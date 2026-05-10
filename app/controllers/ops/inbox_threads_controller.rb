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
      account_id = params.require(:account_id).to_i
      provider = params.require(:provider)

      if params[:anchor_inbox_message_id].present?
        anchor_id = params.require(:anchor_inbox_message_id).to_i
        anchor = InboxMessage.find_by!(account_id: account_id, provider: provider, id: anchor_id)
        raise ActiveRecord::RecordNotFound if anchor.provider_thread_id.present?

        messages = InboxMessage.where(account_id: account_id, provider: provider, id: anchor_id).includes(:booking_request).to_a
        key = [:singleton, account_id, provider, anchor_id]
      else
        tid = params.require(:provider_thread_id)
        messages = InboxMessage.where(account_id: account_id, provider: provider, provider_thread_id: tid).includes(:booking_request).to_a
        key = [:thread, account_id, provider, tid]
      end

      bookings = bookings_for_thread_key(key)
      booking_list = bookings.includes(:drafts).order(created_at: :desc).to_a
      if messages.empty? && booking_list.empty?
        raise ActiveRecord::RecordNotFound
      end

      primary = pick_primary_booking(booking_list)

      render json: {
        inbox_thread: {
          account_id: account_id,
          provider: provider,
          kind: (key[0] == :singleton) ? "singleton" : "thread",
          provider_thread_id: (key[0] == :thread) ? key[3] : nil,
          anchor_inbox_message_id: (key[0] == :singleton) ? key[3] : nil,
          multiple_bookings: booking_list.size > 1,
          booking_request: booking_request_detail(primary),
          timeline: build_timeline(messages, booking_list)
        }
      }
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

    def bookings_for_thread_key(key)
      case key[0]
      when :thread
        BookingRequest.joins(:conversation_thread).where(
          account_id: key[1],
          conversation_threads: {provider_thread_id: key[3]}
        )
      when :singleton
        BookingRequest.where(account_id: key[1], source_inbox_message_id: key[3])
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

    def build_timeline(messages, booking_list)
      items = []

      messages.each do |m|
        items << {
          type: "inbox_message",
          id: m.id,
          direction: m.direction,
          provider_message_id: m.provider_message_id,
          from_name: m.from_name,
          from_email: m.from_email,
          subject: m.subject,
          body_text: m.body_text,
          raw_payload: m.raw_payload,
          sort_at: message_activity_ts(m).iso8601
        }
      end

      booking_list.flat_map(&:drafts).each do |d|
        items << {
          type: "draft",
          id: d.id,
          status: d.status,
          body: d.body,
          default_collapsed: d.rejected?,
          sort_at: draft_sort_ts(d).iso8601
        }
      end

      items.sort_by { |i| Time.zone.parse(i.fetch(:sort_at)) }
    end

    def draft_sort_ts(draft)
      if draft.sent?
        draft.sent_at || draft.updated_at
      else
        draft.created_at
      end
    end
  end
end
