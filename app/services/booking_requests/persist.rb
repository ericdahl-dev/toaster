# frozen_string_literal: true

module BookingRequests
  class Persist
    Result = Struct.new(:booking_request, :contact, :conversation_thread, :message, keyword_init: true)

    def self.call(inbox_message:, raw:, account:)
      new(inbox_message:, account:).call(raw)
    end

    def self.record_inbound(inbox_message:, booking_request:)
      new(inbox_message:, account: inbox_message.account).call_inbound_only(booking_request)
    end

    def initialize(inbox_message:, account:)
      @inbox_message = inbox_message
      @account = account
    end

    def call_inbound_only(booking_request)
      ActiveRecord::Base.transaction do
        contact = find_or_build_contact
        contact.save!

        thread = find_or_build_thread(contact)
        thread.save!

        message = find_or_build_canonical_message(booking_request, thread)

        Result.new(
          booking_request:,
          contact:,
          conversation_thread: thread,
          message:
        )
      end
    end

    def call(raw)
      attempts = 0

      begin
        ActiveRecord::Base.transaction do
          contact = find_or_build_contact
          contact.save!

          thread = find_or_build_thread(contact)
          thread.save!

          booking_request = find_or_build_booking_request(thread, inbox_message)
          booking_request.account = account
          booking_request.contact = contact
          booking_request.conversation_thread = thread

          validation = ValidateExtraction.call(booking_request:, raw:)

          booking_request.assign_attributes(validation.attrs)
          booking_request.review_reasons = []
          booking_request.extraction_snapshot = raw.transform_keys(&:to_s)
          booking_request.status = validation.status
          booking_request.save!

          message = find_or_build_canonical_message(booking_request, thread)

          Result.new(
            booking_request:,
            contact:,
            conversation_thread: thread,
            message:
          )
        end
      rescue ActiveRecord::RecordNotUnique => e
        attempts += 1
        if attempts <= 3
          Rails.logger.warn({
            "event" => "booking_request_persist_retry",
            "attempts" => attempts,
            "error_class" => e.class.name,
            "error_message" => e.message,
            "inbox_message_id" => inbox_message.id
          })
          retry
        else
          Rails.logger.error({
            "event" => "booking_request_persist_failed",
            "attempts" => attempts,
            "error_class" => e.class.name,
            "error_message" => e.message,
            "inbox_message_id" => inbox_message.id
          })
          raise
        end
      end
    end

    private

    attr_reader :inbox_message, :account

    def find_or_build_contact
      normalized_name = inbox_message.from_name.presence || inbox_message.from_email.presence || "Unknown Contact"

      if inbox_message.from_email.present?
        normalized_email = inbox_message.from_email.downcase
        contact = begin
          ActiveRecord::Base.transaction(requires_new: true) do
            account.contacts.find_or_create_by!(email: normalized_email) do |c|
              c.name = normalized_name
            end
          end
        rescue ActiveRecord::RecordNotUnique
          account.contacts.find_by!(email: normalized_email)
        end
        contact.name = normalized_name
        contact
      else
        account.contacts.new(name: normalized_name)
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
      rescue ActiveRecord::RecordNotUnique => e
        attempts += 1

        message = Message.find_by(
          account: inbox_message.account,
          conversation_thread: thread,
          provider_message_id: canonical_message_id
        )

        if message.nil? && attempts <= 3
          Rails.logger.warn({
            "event" => "canonical_message_persist_retry",
            "attempts" => attempts,
            "error_class" => e.class.name,
            "error_message" => e.message,
            "inbox_message_id" => inbox_message.id
          })
          retry
        end

        raise if message.nil?

        message
      end
    end

    def find_or_build_booking_request(thread, inbox_message)
      ThreadLookup.booking_request_for_thread(thread) ||
        BookingRequest.new(source_inbox_message: inbox_message)
    end

    def find_or_build_thread(contact)
      thread = ThreadLookup.conversation_thread_for(inbox_message)
      thread ||= inbox_message.account.conversation_threads.new(
        provider_thread_id: ConversationThreading.canonical_id_for(inbox_message)
      )
      thread.tap do |t|
        t.contact = contact
        t.subject = inbox_message.subject
      end
    end

    def canonical_message_id
      "#{inbox_message.provider}:#{inbox_message.provider_message_id}"
    end
  end
end
