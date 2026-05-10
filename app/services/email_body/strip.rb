# frozen_string_literal: true

module EmailBody
  module Strip
    QUOTED_REPLY_HEADER = /^On .+ wrote:$/m
    ORIGINAL_MESSAGE_BLOCK = /^-{2,}\s*Original Message/m
    SIGNATURE = /^-- $/m

    def self.call(body)
      return "" if body.blank?

      text = body.dup
      text = text.split(QUOTED_REPLY_HEADER).first
      text = text.split(ORIGINAL_MESSAGE_BLOCK).first
      text = text.split(SIGNATURE).first
      text.strip
    end
  end
end
