# frozen_string_literal: true

module Ops
  class InboxThreadsController < ApplicationController
    skip_forgery_protection
    include Ops::RequireToken
    include Ops::BookingPayload

    THREAD_LIMIT = 50
    MESSAGE_SCAN_LIMIT = 400

    def index
      recent = InboxMessage
        .includes(:booking_request)
        .order(Arel.sql("COALESCE(received_at, created_at) DESC"))
        .limit(MESSAGE_SCAN_LIMIT)
        .to_a

      buckets = Hash.new { |h, k| h[k] = [] }
      recent.each { |m| buckets[thread_key_for(m)] << m }

      activity = {}
      buckets.each_key do |key|
        msgs = buckets[key]
        activity[key] = msgs.map { |m| message_activity_ts(m) }.max
      end
      merge_draft_peaks!(activity)

      sorted_keys = activity.sort_by { |_, t| -t.to_f }.first(THREAD_LIMIT).map(&:first)

      render json: {
        inbox_threads: sorted_keys.map { |key| build_thread_list_row(key, buckets[key], activity[key]) }
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

    def thread_key_for(message)
      if message.provider_thread_id.present?
        [:thread, message.account_id, message.provider, message.provider_thread_id]
      else
        [:singleton, message.account_id, message.provider, message.id]
      end
    end

    def message_activity_ts(message)
      message.received_at || message.created_at
    end

    def merge_draft_peaks!(activity)
      connection = ActiveRecord::Base.connection
      connection.select_all(sanitized_draft_peaks_thread_sql).each do |row|
        key = [:thread, row["account_id"].to_i, row["provider"], row["provider_thread_id"]]
        peak = parse_sql_time(row["peak"])
        activity[key] = [activity[key], peak].compact.max
      end

      connection.select_all(sanitized_draft_peaks_singleton_sql).each do |row|
        key = [:singleton, row["account_id"].to_i, row["provider"], row["anchor_id"].to_i]
        peak = parse_sql_time(row["peak"])
        activity[key] = [activity[key], peak].compact.max
      end
    end

    def sanitized_draft_peaks_thread_sql
      <<~SQL.squish
        SELECT booking_requests.account_id,
               inbox_messages.provider,
               conversation_threads.provider_thread_id,
               MAX(CASE
                 WHEN drafts.status = 'sent' THEN COALESCE(drafts.sent_at, drafts.updated_at)
                 ELSE drafts.created_at
               END) AS peak
        FROM drafts
        INNER JOIN booking_requests ON booking_requests.id = drafts.booking_request_id
        INNER JOIN conversation_threads ON conversation_threads.id = booking_requests.conversation_thread_id
        INNER JOIN inbox_messages ON inbox_messages.id = booking_requests.source_inbox_message_id
        WHERE conversation_threads.provider_thread_id IS NOT NULL
        GROUP BY booking_requests.account_id, inbox_messages.provider, conversation_threads.provider_thread_id
      SQL
    end

    def sanitized_draft_peaks_singleton_sql
      <<~SQL.squish
        SELECT booking_requests.account_id,
               inbox_messages.provider,
               inbox_messages.id AS anchor_id,
               MAX(CASE
                 WHEN drafts.status = 'sent' THEN COALESCE(drafts.sent_at, drafts.updated_at)
                 ELSE drafts.created_at
               END) AS peak
        FROM drafts
        INNER JOIN booking_requests ON booking_requests.id = drafts.booking_request_id
        INNER JOIN inbox_messages ON inbox_messages.id = booking_requests.source_inbox_message_id
        WHERE inbox_messages.provider_thread_id IS NULL
        GROUP BY booking_requests.account_id, inbox_messages.provider, inbox_messages.id
      SQL
    end

    def parse_sql_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    end

    def build_thread_list_row(key, cached_messages, last_activity_at)
      messages = if cached_messages.present?
        cached_messages
      else
        messages_for_thread_key(key)
      end
      preview = preview_message(messages)

      bookings = bookings_for_thread_key(key)
      primary = pick_primary_booking(bookings.order(created_at: :desc).to_a)

      {
        account_id: key[1],
        provider: key[2],
        kind: (key[0] == :singleton) ? "singleton" : "thread",
        provider_thread_id: (key[0] == :thread) ? key[3] : nil,
        anchor_inbox_message_id: (key[0] == :singleton) ? key[3] : nil,
        subject: preview&.subject,
        from_name: preview&.from_name,
        from_email: preview&.from_email,
        last_activity_at: last_activity_at&.iso8601,
        booking_request: booking_request_summary(primary)
      }
    end

    def messages_for_thread_key(key)
      case key[0]
      when :thread
        InboxMessage.where(account_id: key[1], provider: key[2], provider_thread_id: key[3]).includes(:booking_request).to_a
      when :singleton
        InboxMessage.where(account_id: key[1], provider: key[2], id: key[3]).includes(:booking_request).to_a
      end
    end

    def preview_message(messages)
      inbound = messages.select(&:inbound?)
      pool = inbound.presence || messages
      pool.max_by { |m| message_activity_ts(m) }
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
