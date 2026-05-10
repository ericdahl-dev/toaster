# frozen_string_literal: true

module Drafts
  class MailBuilder
    def initialize(draft:)
      @draft = draft
    end

    def subject_line
      last_subject = booking_request.source_inbox_message&.subject
      return "Re: #{last_subject}" if last_subject.present? && !last_subject.start_with?("Re:")
      last_subject.presence || "Re: your inquiry"
    end

    def build_outbound_message_attrs(body_text:, sent_at:)
      {
        account: draft.account,
        conversation_thread: booking_request.conversation_thread,
        booking_request: booking_request,
        direction: :outbound,
        body_text: body_text,
        sent_at: sent_at
      }
    end

    private

    attr_reader :draft

    def booking_request
      @booking_request ||= draft.booking_request
    end
  end
end
