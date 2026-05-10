# frozen_string_literal: true

module Ops
  class InboxThreadsController < ApplicationController
    skip_forgery_protection
    include Ops::RequireToken
    include Ops::BookingPayload

    def index
      feed = Ops::ActivityFeed.call
      render json: {
        inbox_threads: feed.map { |row| build_thread_list_row(row) }
      }
    end

    def show
      result = Ops::ThreadView.call(
        account_id: params.require(:account_id).to_i,
        provider: params.require(:provider),
        provider_thread_id: params[:provider_thread_id],
        anchor_inbox_message_id: params[:anchor_inbox_message_id]&.to_i
      )
      render json: {inbox_thread: result}
    rescue ActiveRecord::RecordNotFound
      render json: {error: "Inbox thread not found"}, status: :not_found
    end

    private

    def message_activity_ts(message)
      message.received_at || message.created_at
    end

    def build_thread_list_row(row)
      messages = messages_for_row(row)
      preview = preview_message(messages)

      bookings = bookings_for_row(row)
      primary = pick_primary_booking(bookings.order(created_at: :desc).to_a)

      {
        account_id: row.account_id,
        provider: row.provider,
        kind: row.kind,
        provider_thread_id: row.provider_thread_id,
        anchor_inbox_message_id: row.anchor_inbox_message_id,
        subject: preview&.subject,
        from_name: preview&.from_name,
        from_email: preview&.from_email,
        last_activity_at: row.last_activity_at&.iso8601,
        booking_request: booking_request_summary(primary)
      }
    end

    def messages_for_row(row)
      if row.kind == "thread"
        InboxMessage.where(account_id: row.account_id, provider: row.provider, provider_thread_id: row.provider_thread_id).includes(:booking_request).to_a
      else
        InboxMessage.where(account_id: row.account_id, provider: row.provider, id: row.anchor_inbox_message_id).includes(:booking_request).to_a
      end
    end

    def bookings_for_row(row)
      if row.kind == "thread"
        BookingRequest.joins(:conversation_thread).where(
          account_id: row.account_id,
          conversation_threads: {provider_thread_id: row.provider_thread_id}
        )
      else
        BookingRequest.where(account_id: row.account_id, source_inbox_message_id: row.anchor_inbox_message_id)
      end
    end

    def preview_message(messages)
      inbound = messages.select(&:inbound?)
      pool = inbound.presence || messages
      pool.max_by { |m| message_activity_ts(m) }
    end

    def pick_primary_booking(booking_list)
      return nil if booking_list.empty?

      booking_list.find { |br| %w[pending reviewing].include?(br.status) } || booking_list.max_by(&:created_at)
    end
  end
end
