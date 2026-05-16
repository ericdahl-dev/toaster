# frozen_string_literal: true

module Ops
  class ActivityFeed
    Row = Data.define(:account_id, :provider, :kind, :provider_thread_id, :anchor_inbox_message_id, :last_activity_at)

    def self.call(limit: 50)
      new(limit: limit).call
    end

    def initialize(limit: 50)
      @limit = limit
    end

    def call
      activity = {}

      connection.select_all(message_peaks_sql).each do |row|
        key = build_key(row)
        peak = parse_sql_time(row["peak"])
        activity[key] = peak
      end

      merge_draft_peaks!(activity)

      sorted_keys = activity.sort_by { |_, t| -t.to_f }.first(@limit).map(&:first)
      sorted_keys.map { |key| build_row(key, activity[key]) }
    end

    private

    def connection
      ActiveRecord::Base.connection
    end

    def message_peaks_sql
      <<~SQL.squish
        SELECT
          account_id,
          provider,
          CASE WHEN provider_thread_id IS NOT NULL THEN 'thread' ELSE 'singleton' END AS kind,
          provider_thread_id,
          CASE WHEN provider_thread_id IS NULL THEN id ELSE NULL END AS anchor_inbox_message_id,
          MAX(COALESCE(received_at, created_at)) AS peak
        FROM inbox_messages
        GROUP BY
          account_id,
          provider,
          kind,
          provider_thread_id,
          anchor_inbox_message_id
      SQL
    end

    def merge_draft_peaks!(activity)
      connection.select_all(draft_peaks_thread_sql).each do |row|
        key = [ :thread, row["account_id"].to_i, row["provider"], row["provider_thread_id"] ]
        peak = parse_sql_time(row["peak"])
        activity[key] = [ activity[key], peak ].compact.max
      end

      connection.select_all(draft_peaks_singleton_sql).each do |row|
        key = [ :singleton, row["account_id"].to_i, row["provider"], row["anchor_id"].to_i ]
        peak = parse_sql_time(row["peak"])
        activity[key] = [ activity[key], peak ].compact.max
      end
    end

    def draft_peaks_thread_sql
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

    def draft_peaks_singleton_sql
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

    def build_key(row)
      kind = row["kind"]
      if kind == "thread"
        [ :thread, row["account_id"].to_i, row["provider"], row["provider_thread_id"] ]
      else
        [ :singleton, row["account_id"].to_i, row["provider"], row["anchor_inbox_message_id"].to_i ]
      end
    end

    def parse_sql_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    end

    def build_row(key, last_activity_at)
      kind = (key[0] == :singleton) ? "singleton" : "thread"
      Row.new(
        account_id: key[1],
        provider: key[2],
        kind: kind,
        provider_thread_id: (key[0] == :thread) ? key[3] : nil,
        anchor_inbox_message_id: (key[0] == :singleton) ? key[3] : nil,
        last_activity_at: last_activity_at
      )
    end
  end
end
