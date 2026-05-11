class Message < ApplicationRecord
  belongs_to :account
  belongs_to :conversation_thread
  belongs_to :booking_request, optional: true

  enum :direction, { inbound: "inbound", outbound: "outbound" }

  validates :direction, presence: true
  validates :provider_message_id, uniqueness: { scope: :account_id }, allow_nil: true

  validate :conversation_thread_belongs_to_account
  validate :booking_request_belongs_to_account

  after_create_commit :broadcast_inbound_to_timeline, if: -> { inbound? && booking_request_id? }

  private

  def broadcast_inbound_to_timeline
    html = ApplicationController.renderer.render(
      partial: "messages/inbound_bubble",
      locals: { message: self }
    )
    Turbo::StreamsChannel.broadcast_append_to(
      booking_request,
      target: "thread-timeline",
      html: html
    )
  end

  def conversation_thread_belongs_to_account
    return unless conversation_thread && account
    if conversation_thread.account_id != account_id
      errors.add(:conversation_thread, "must belong to the same account")
    end
  end

  def booking_request_belongs_to_account
    return unless booking_request && account
    if booking_request.account_id != account_id
      errors.add(:booking_request, "must belong to the same account")
    end
  end
end
