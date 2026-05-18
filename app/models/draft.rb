class Draft < ApplicationRecord
  belongs_to :account
  belongs_to :booking_request

  enum :status, {
    pending_review: "pending_review",
    approved: "approved",
    modified: "modified",
    rejected: "rejected",
    sent: "sent"
  }

  validates :body, presence: true
  validates :status, presence: true

  validate :booking_request_belongs_to_account

  after_create_commit :broadcast_pending_to_timeline, if: -> { pending_review? }

  private

  def broadcast_pending_to_timeline
    TurboTimelineBroadcast.deliver(booking_request: booking_request, operation: "append_pending_draft") do
      html = ApplicationController.renderer.render(
        partial: "drafts/pending_bubble",
        locals: { draft: self }
      )
      Turbo::StreamsChannel.broadcast_append_to(
        booking_request,
        target: "thread-timeline",
        html: html
      )
    end
  end

  def booking_request_belongs_to_account
    return unless booking_request && account
    if booking_request.account_id != account_id
      errors.add(:booking_request, "must belong to the same account")
    end
  end
end
