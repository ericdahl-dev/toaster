# frozen_string_literal: true

module Ops
  class InboxThreadsController < ApplicationController
    skip_forgery_protection
    include Ops::RequireToken
    include Ops::BookingPayload

    def index
      feed = Ops::ActivityFeed.call
      messages_by_thread, messages_by_id, bookings_by_thread, bookings_by_message = batch_load(feed)

      render json: {
        inbox_threads: feed.map { |row|
          build_thread_list_row(row, messages_by_thread, messages_by_id, bookings_by_thread, bookings_by_message)
        }
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

    def batch_load(feed)
      thread_rows = feed.select { |r| r.kind == "thread" }
      singleton_rows = feed.select { |r| r.kind == "singleton" }

      [
        load_thread_messages(thread_rows),
        load_singleton_messages(singleton_rows),
        load_thread_bookings(thread_rows),
        load_singleton_bookings(singleton_rows)
      ]
    end

    def load_thread_messages(thread_rows)
      return {} if thread_rows.empty?

      thread_ids = thread_rows.map(&:provider_thread_id).compact.uniq
      InboxMessage
        .where(provider_thread_id: thread_ids)
        .to_a
        .group_by { |m| [m.account_id, m.provider, m.provider_thread_id] }
    end

    def load_singleton_messages(singleton_rows)
      return {} if singleton_rows.empty?

      ids = singleton_rows.map(&:anchor_inbox_message_id).compact
      InboxMessage.where(id: ids).index_by(&:id)
    end

    def load_thread_bookings(thread_rows)
      return {} if thread_rows.empty?

      thread_ids = thread_rows.map(&:provider_thread_id).compact.uniq
      BookingRequest
        .joins(:conversation_thread)
        .where(conversation_threads: {provider_thread_id: thread_ids})
        .includes(:conversation_thread)
        .to_a
        .group_by { |br| br.conversation_thread.provider_thread_id }
    end

    def load_singleton_bookings(singleton_rows)
      return {} if singleton_rows.empty?

      ids = singleton_rows.map(&:anchor_inbox_message_id).compact
      BookingRequest.where(source_inbox_message_id: ids).group_by(&:source_inbox_message_id)
    end

    def message_activity_ts(message)
      message.received_at || message.created_at
    end

    def build_thread_list_row(row, messages_by_thread, messages_by_id, bookings_by_thread, bookings_by_message)
      messages = if row.kind == "thread"
        messages_by_thread[[row.account_id, row.provider, row.provider_thread_id]] || []
      else
        [messages_by_id[row.anchor_inbox_message_id]].compact
      end

      preview = preview_message(messages)

      booking_list = if row.kind == "thread"
        (bookings_by_thread[row.provider_thread_id] || []).sort_by(&:created_at).reverse
      else
        (bookings_by_message[row.anchor_inbox_message_id] || []).sort_by(&:created_at).reverse
      end

      primary = pick_primary_booking(booking_list)

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
