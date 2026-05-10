# frozen_string_literal: true

module Drafts
  # Creates the outbound Message record and auto-confirms the BookingRequest
  # after a draft has been sent (via SMTP or IMAP reconciliation).
  class CompleteSend
    def self.call(draft:, sent_body:, actor:)
      new(draft: draft, sent_body: sent_body, actor: actor).call
    end

    def initialize(draft:, sent_body:, actor:)
      @draft = draft
      @sent_body = sent_body
      @actor = actor
    end

    def call
      create_outbound_message
      confirm_booking_request
    end

    private

    attr_reader :draft, :sent_body, :actor

    def create_outbound_message
      attrs = Drafts::MailBuilder.new(draft: draft).build_outbound_message_attrs(
        body_text: sent_body,
        sent_at: draft.sent_at || Time.current
      )
      Message.create!(attrs)
    end

    def confirm_booking_request
      booking_request = draft.booking_request
      return unless booking_request.reviewing?

      BookingRequests::Transition.call(
        booking_request: booking_request,
        to: "confirmed",
        metadata: {actor: actor}
      )
    end
  end
end
