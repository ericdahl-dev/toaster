# frozen_string_literal: true

module Drafts
  # Rejects a draft, marking it as no longer under review.
  #
  # Always returns :ok. Calling reject on an already-rejected draft is a no-op
  # on the status field (idempotent).
  class Reject
    def self.call(draft:)
      new(draft: draft).call
    end

    def initialize(draft:)
      @draft = draft
    end

    def call
      draft.update!(status: :rejected)
      :ok
    end

    private

    attr_reader :draft
  end
end
