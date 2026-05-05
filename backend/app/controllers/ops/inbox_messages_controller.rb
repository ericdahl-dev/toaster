module Ops
  class InboxMessagesController < ApplicationController
    skip_forgery_protection
    include Ops::RequireToken
    include Ops::BookingPayload

    def index
      messages = InboxMessage
        .inbound
        .includes(:booking_request)
        .order(received_at: :desc, created_at: :desc)
        .limit(100)

      render json: {
        inbox_messages: messages.map do |message|
          {
            id: message.id,
            provider: message.provider,
            provider_message_id: message.provider_message_id,
            provider_thread_id: message.provider_thread_id,
            direction: message.direction,
            from_name: message.from_name,
            from_email: message.from_email,
            subject: message.subject,
            received_at: message.received_at,
            booking_request: booking_request_summary(message.booking_request)
          }
        end
      }
    end

    def show
      message = InboxMessage.inbound.includes(:booking_request).find(params[:id])

      render json: {
        inbox_message: {
          id: message.id,
          provider: message.provider,
          provider_message_id: message.provider_message_id,
          provider_thread_id: message.provider_thread_id,
          direction: message.direction,
          from_name: message.from_name,
          from_email: message.from_email,
          to_emails: message.to_emails,
          subject: message.subject,
          body_text: message.body_text,
          body_html: message.body_html,
          received_at: message.received_at,
          raw_payload: message.raw_payload,
          booking_request: booking_request_detail(message.booking_request)
        }
      }
    rescue ActiveRecord::RecordNotFound
      render json: {error: "Inbox message not found"}, status: :not_found
    end
  end
end
