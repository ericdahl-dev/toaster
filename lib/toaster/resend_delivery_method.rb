# frozen_string_literal: true

require "json"
require "net/http"

module Toaster
  class ResendDeliveryMethod
    class DeliveryError < StandardError; end

    RESEND_EMAILS_URI = URI("https://api.resend.com/emails")

    def initialize(settings)
      @settings = settings
    end

    def deliver!(mail)
      response = Net::HTTP.start(RESEND_EMAILS_URI.host, RESEND_EMAILS_URI.port, use_ssl: true) do |http|
        http.request(build_request(mail))
      end

      return response if response.is_a?(Net::HTTPSuccess)

      raise DeliveryError, "Resend delivery failed (#{response.code}): #{response.body}"
    end

    private

    attr_reader :settings

    def build_request(mail)
      request = Net::HTTP::Post.new(RESEND_EMAILS_URI)
      request["Authorization"] = "Bearer #{settings.fetch(:api_key)}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload_for(mail))
      request
    end

    def payload_for(mail)
      {
        from: settings.fetch(:from),
        to: Array(mail.to),
        cc: Array(mail.cc).presence,
        bcc: Array(mail.bcc).presence,
        reply_to: Array(mail.reply_to).presence,
        subject: mail.subject,
        html: mail.html_part&.decoded,
        text: mail.text_part&.decoded || mail.body&.decoded
      }.compact
    end
  end
end
