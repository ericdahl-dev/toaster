# frozen_string_literal: true

module BookingRequests
  class Extract
    def self.call(inbox_message:, venue: nil)
      new(inbox_message:, venue:).call
    end

    def initialize(inbox_message:, venue: nil)
      @inbox_message = inbox_message
      @venue = venue
    end

    def call
      account = inbox_message.account
      stripped_body = InboundContext.prepare_text(inbox_message)

      is_booking = Classifier.new(account:).call(
        subject: inbox_message.subject,
        body_text: stripped_body
      )
      return nil unless is_booking

      venue_chunks = InboundContext.venue_chunks(venue: venue, text: stripped_body, subject: inbox_message.subject)
      raw = LlmExtractor.new(account:, venue_chunks:).call(
        subject: inbox_message.subject,
        body_text: stripped_body
      )

      Persist.call(inbox_message:, raw:, account:)
    end

    private

    attr_reader :inbox_message, :venue
  end
end
