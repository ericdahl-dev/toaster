# frozen_string_literal: true

module InboxIngestion
  # Matches an inbox message subject against an ImapConnection's ordered
  # InboxFilter rules and returns the first matching Venue, or nil.
  class FilterMatcher
    def initialize(imap_connection:)
      @filters = imap_connection.inbox_filters.includes(:venue)
    end

    def match(subject:)
      return nil if subject.blank?

      downcased = subject.downcase
      @filters.each do |filter|
        return filter.venue if downcased.include?(filter.keyword.downcase)
      end
      nil
    end
  end
end
