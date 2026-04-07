module AgentMailbox
  class ExtractBookingRequest
    Result = Struct.new(:booking_request, :contact, :conversation_thread, :message, keyword_init: true)

    MONTH_NAME_DATE = /\b(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+\d{1,2}(?:,\s*\d{4})?\b/i
    HEADCOUNT = /\b(\d{1,4})\s+(?:guests?|people|attendees?)\b/i
    BUDGET = /\$\s?(\d[\d,]*(?:\.\d{2})?)/

    def self.call(inbox_message:)
      new(inbox_message: inbox_message).call
    end

    def initialize(inbox_message:)
      @inbox_message = inbox_message
    end

    def call
      attempts = 0

      begin
        ActiveRecord::Base.transaction do
          contact = find_or_build_contact
          contact.save!

          thread = find_or_build_thread(contact)
          thread.save!

          extracted = extract_fields

          booking_request = BookingRequest.find_or_initialize_by(source_inbox_message: inbox_message)
          booking_request.account = inbox_message.account
          booking_request.contact = contact
          booking_request.conversation_thread = thread
          booking_request.event_date = extracted[:event_date]
          booking_request.headcount = extracted[:headcount]
          booking_request.budget_cents = extracted[:budget_cents]
          booking_request.extraction_snapshot = extracted[:snapshot]
          booking_request.missing_fields = extracted[:missing_fields]
          booking_request.review_reasons = extracted[:review_reasons]
          booking_request.status = extracted[:status]
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

    private

    attr_reader :inbox_message

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

    def extract_fields
      event_dates = extract_event_dates
      headcounts = extract_headcounts
      budgets = extract_budgets

      review_reasons = []

      event_date = single_value(event_dates) do
        review_reasons << "ambiguous_event_date"
      end
      headcount = single_value(headcounts) do
        review_reasons << "ambiguous_headcount"
      end
      budget_cents = single_value(budgets) do
        review_reasons << "ambiguous_budget_cents"
      end

      missing_fields = []
      missing_fields << "event_date" if event_date.nil?
      missing_fields << "headcount" if headcount.nil?
      missing_fields << "budget_cents" if budget_cents.nil?

      snapshot = {
        "event_date" => event_date&.iso8601,
        "headcount" => headcount,
        "budget_cents" => budget_cents
      }

      {
        event_date: event_date,
        headcount: headcount,
        budget_cents: budget_cents,
        missing_fields: missing_fields,
        review_reasons: review_reasons,
        snapshot: snapshot,
        status: (missing_fields.any? || review_reasons.any?) ? "reviewing" : "pending"
      }
    end

    def extract_event_dates
      source_text.scan(MONTH_NAME_DATE).filter_map do |match|
        next unless match.match?(/\d{4}/)

        begin
          Date.parse(match)
        rescue Date::Error
          nil
        end
      end.uniq.sort
    end

    def extract_headcounts
      source_text.scan(HEADCOUNT).flatten.map(&:to_i).uniq.sort
    end

    def extract_budgets
      source_text.scan(BUDGET).flatten.map do |raw|
        normalized = raw.delete(",")
        (BigDecimal(normalized) * 100).to_i
      end.uniq.sort
    end

    def single_value(values)
      return values.first if values.one?
      yield if values.many?
      nil
    end

    def source_text
      @source_text ||= [inbox_message.subject, inbox_message.body_text].compact.join("\n")
    end
  end
end
