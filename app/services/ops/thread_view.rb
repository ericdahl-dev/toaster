# frozen_string_literal: true

module Ops
  # Builds the JSON payload for a single inbox thread (show action).
  # Accepts either a provider_thread_id (normal thread) or an
  # anchor_inbox_message_id (singleton message with no thread).
  class ThreadView
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(account_id:, provider:, provider_thread_id: nil, anchor_inbox_message_id: nil)
      @account_id = account_id
      @provider = provider
      @provider_thread_id = provider_thread_id
      @anchor_inbox_message_id = anchor_inbox_message_id
    end

    def call
      if anchor_inbox_message_id.present?
        anchor = InboxMessage.find_by!(account_id: account_id, provider: provider, id: anchor_inbox_message_id)
        raise ActiveRecord::RecordNotFound if anchor.provider_thread_id.present?

        messages = InboxMessage.where(account_id: account_id, provider: provider, id: anchor_inbox_message_id).includes(:booking_request).to_a
        key = [ :singleton, account_id, provider, anchor_inbox_message_id ]
      else
        raise ActiveRecord::RecordNotFound unless provider_thread_id.present?

        messages = InboxMessage.where(account_id: account_id, provider: provider, provider_thread_id: provider_thread_id).includes(:booking_request).to_a
        key = [ :thread, account_id, provider, provider_thread_id ]
      end

      bookings = bookings_for_key(key)
      booking_list = bookings.includes(:drafts).order(created_at: :desc).to_a

      raise ActiveRecord::RecordNotFound if messages.empty? && booking_list.empty?

      primary = pick_primary(booking_list)

      {
        account_id: account_id,
        provider: provider,
        kind: (key[0] == :singleton) ? "singleton" : "thread",
        provider_thread_id: (key[0] == :thread) ? key[3] : nil,
        anchor_inbox_message_id: (key[0] == :singleton) ? key[3] : nil,
        multiple_bookings: booking_list.size > 1,
        booking_request: booking_request_detail(primary),
        timeline: build_timeline(messages, booking_list)
      }
    end

    private

    attr_reader :account_id, :provider, :provider_thread_id, :anchor_inbox_message_id

    def bookings_for_key(key)
      case key[0]
      when :thread
        BookingRequest.joins(:conversation_thread).where(
          account_id: key[1],
          conversation_threads: {
            provider_thread_id: ConversationThreading.canonical_id_for_inbox_thread(
              provider: key[2],
              inbox_thread_id: key[3]
            )
          }
        )
      when :singleton
        BookingRequest.where(account_id: key[1], source_inbox_message_id: key[3])
      end
    end

    def pick_primary(booking_list)
      return nil if booking_list.empty?

      booking_list.find { |br| %w[pending reviewing].include?(br.status) } || booking_list.max_by(&:created_at)
    end

    def booking_request_detail(booking_request)
      return nil unless booking_request

      pending_draft = booking_request.drafts.find_by(status: :pending_review)

      {
        id: booking_request.id,
        status: booking_request.status,
        event_date: booking_request.event_date,
        headcount: booking_request.headcount,
        budget: booking_request.budget,
        missing_fields: booking_request.missing_fields,
        review_reasons: booking_request.review_reasons,
        extraction_snapshot: booking_request.extraction_snapshot,
        pending_draft: pending_draft ? { id: pending_draft.id, body: pending_draft.body } : nil
      }
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
          sort_at: message_ts(m).iso8601
        }
      end

      booking_list.flat_map(&:drafts).each do |d|
        items << {
          type: "draft",
          id: d.id,
          status: d.status,
          body: d.body,
          default_collapsed: d.rejected?,
          sort_at: draft_ts(d).iso8601
        }
      end

      items.sort_by { |i| Time.zone.parse(i.fetch(:sort_at)) }
    end

    def message_ts(message)
      message.received_at || message.created_at
    end

    def draft_ts(draft)
      if draft.sent?
        draft.sent_at || draft.updated_at
      else
        draft.created_at
      end
    end
  end
end
