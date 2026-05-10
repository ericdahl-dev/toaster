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

      Persist.call(inbox_message:, raw:, account:)
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
  end
end
