# frozen_string_literal: true

module Drafts
  # Approves a draft and enqueues outbound delivery.
  #
  # Possible return values:
  #   :already_sent  — draft is already sent; caller should redirect with notice
  #   :not_pending   — draft is in a state that cannot transition to approved (e.g. rejected)
  #   :ok            — draft was approved (or was already approved) and SendDraftJob was enqueued
  #
  # The approval + job enqueue are not atomic, but SendDraftJob is idempotent:
  # it re-checks status inside a row lock and is no-oped if already sent.
  class Approve
    def self.call(draft:)
      new(draft: draft).call
    end

    def initialize(draft:)
      @draft = draft
    end

    def call
      result = nil

      draft.with_lock do
        if draft.sent?
          result = :already_sent
          next
        end

        unless draft.pending_review? || draft.approved?
          result = :not_pending
          next
        end

        draft.update!(status: :approved) unless draft.approved?
        result = :ok
      end

      SendDraftJob.perform_later(draft.id) if result == :ok

      result
    end

    private

    attr_reader :draft
  end
end
