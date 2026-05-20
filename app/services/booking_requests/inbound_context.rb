# frozen_string_literal: true

module BookingRequests
  module InboundContext
    def self.prepare_text(inbox_message)
      EmailBody::Strip.call(inbox_message.body_text)
    end

    def self.venue_chunks(venue:, text:, subject: "")
      return [] if venue.nil?

      VenueKnowledge.for(venue: venue, query: "#{subject} #{text}")
    end
  end
end
