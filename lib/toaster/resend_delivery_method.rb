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
      ensure_api_key!

      response = Net::HTTP.start(RESEND_EMAILS_URI.host, RESEND_EMAILS_URI.port, use_ssl: true) do |http|
        http.request(build_request(mail))
      end

      return response if response.is_a?(Net::HTTPSuccess)

      raise DeliveryError, "Resend delivery failed (#{response.code}): #{response.body}"
    rescue DeliveryError
      raise
    rescue StandardError => e
      raise DeliveryError, "Resend delivery failed: #{e.message}"
    end

    private

    attr_reader :settings

    def ensure_api_key!
      return if settings[:api_key].present?

      raise DeliveryError, "Resend delivery failed: RESEND_API_KEY is not configured"
    end

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
        to: recipient_list(mail.to),
        cc: recipient_list(mail.cc),
        bcc: recipient_list(mail.bcc),
        reply_to: recipient_list(mail.reply_to),
        subject: mail.subject,
        html: mail.html_part&.decoded,
        text: mail.text_part&.decoded || mail.body&.decoded
      }.compact
    end

    def recipient_list(value)
      Array(value).map { |recipient| recipient.to_s.strip }.reject(&:blank?).presence
    end
  end
end
