# frozen_string_literal: true

module BookingRequests
  class Extract
    Result = Struct.new(:booking_request, :contact, :conversation_thread, :message, keyword_init: true)

    def self.call(inbox_message:, venue: nil)
      new(inbox_message: inbox_message, venue: venue).call
    end

    def initialize(inbox_message:, venue: nil)
      @inbox_message = inbox_message
      @venue = venue
    end

    def call
      account = inbox_message.account
      stripped_body = EmailBody::Strip.call(inbox_message.body_text)

      is_booking = Classifier.new(account:).call(
        subject: inbox_message.subject,
        body_text: stripped_body
      )
      return nil unless is_booking

      venue_chunks = retrieve_venue_chunks(subject: inbox_message.subject, body_text: stripped_body)
      raw = LlmExtractor.new(account:, venue_chunks:).call(
        subject: inbox_message.subject,
        body_text: stripped_body
      )

      persist(account:, raw:)
    end

    private

    attr_reader :inbox_message, :venue

    def retrieve_venue_chunks(subject:, body_text:)
      return [] if venue.nil?

      VenueRagRetriever.call(
        venue: venue,
        query: "#{subject} #{body_text}"
      )
    end

    def persist(account:, raw:)
      attempts = 0

      begin
        ActiveRecord::Base.transaction do
          contact = find_or_build_contact
          contact.save!

          thread = find_or_build_thread(contact)
          thread.save!

          booking_request = BookingRequest.find_or_initialize_by(source_inbox_message: inbox_message)
          booking_request.account = account
          booking_request.contact = contact
          booking_request.conversation_thread = thread

          validated = ValidateExtraction.new(booking_request:).call(raw)
          status = Decisioner.call(validated)

          booking_request.event_date = validated[:event_date]
          booking_request.headcount = validated[:headcount]
          booking_request.budget = validated[:budget]
          booking_request.start_time = validated[:start_time]
          booking_request.celebration_type = validated[:celebration_type]
          booking_request.fit_status = validated[:fit_status]
          booking_request.staff_summary = validated[:staff_summary]
          booking_request.missing_fields = validated[:missing_fields]
          booking_request.review_reasons = []
          booking_request.extraction_snapshot = raw.transform_keys(&:to_s)
          booking_request.status = status
          booking_request.save!

          message = find_or_build_canonical_message(booking_request, thread)

          Result.new(
            booking_request: booking_request,
            contact: contact,
            conversation_thread: thread,
            message: message
          )
        end
      rescue ActiveRecord::RecordNotUnique
        attempts += 1
        retry if attempts <= 3
        raise
      end
    end

    def find_or_build_contact
      account = inbox_message.account

      if inbox_message.from_email.present?
        normalized_email = inbox_message.from_email.downcase

        account.with_lock do
          contact = account.contacts.find_by(email: normalized_email)
          contact ||= account.contacts.new(email: normalized_email)
          contact.name = inbox_message.from_name.presence || inbox_message.from_email.presence || "Unknown Contact"
          contact
        end
      else
        account.contacts.new.tap do |contact|
          contact.name = inbox_message.from_name.presence || inbox_message.from_email.presence || "Unknown Contact"
        end
      end
    end

    def find_or_build_canonical_message(booking_request, thread)
      attempts = 0

      begin
        message = Message.find_or_initialize_by(
          account: inbox_message.account,
          conversation_thread: thread,
          provider_message_id: canonical_message_id
        )
        message.booking_request = booking_request
        message.direction = inbox_message.direction
        message.body_text = inbox_message.body_text
        message.body_html = inbox_message.body_html
        message.sent_at = inbox_message.received_at
        message.save!
        message
      rescue ActiveRecord::RecordNotUnique
        attempts += 1

        message = Message.find_by(
          account: inbox_message.account,
          conversation_thread: thread,
          provider_message_id: canonical_message_id
        )

        retry if message.nil? && attempts <= 3
        raise if message.nil?

        message
      end
    end

    def find_or_build_thread(contact)
      inbox_message.account.conversation_threads.find_or_initialize_by(provider_thread_id: canonical_thread_id).tap do |thread|
        thread.contact = contact
        thread.subject = inbox_message.subject
      end
    end

    def canonical_thread_id
      "#{inbox_message.provider}:#{inbox_message.provider_thread_id.presence || inbox_message.provider_message_id}"
    end

    def canonical_message_id
      "#{inbox_message.provider}:#{inbox_message.provider_message_id}"
    end
  end
end
