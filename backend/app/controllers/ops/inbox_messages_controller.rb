module Ops
  class InboxMessagesController < ApplicationController
    before_action :require_ops_auth!

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

    private

    def require_ops_auth!
      token = ENV["OPS_AUTH_TOKEN"].presence
      return unless token

      provided = request.headers["X-Ops-Token"]
      return if ActiveSupport::SecurityUtils.secure_compare(provided.to_s, token)

      render json: {error: "Unauthorized"}, status: :unauthorized
    end

    def booking_request_summary(booking_request)
      return nil unless booking_request

      {
        id: booking_request.id,
        status: booking_request.status
      }
    end

    def booking_request_detail(booking_request)
      return nil unless booking_request

      {
        id: booking_request.id,
        status: booking_request.status,
        event_date: booking_request.event_date,
        headcount: booking_request.headcount,
        budget_cents: booking_request.budget_cents,
        missing_fields: booking_request.missing_fields,
        review_reasons: booking_request.review_reasons,
        extraction_snapshot: booking_request.extraction_snapshot
      }
    end
  end
end
