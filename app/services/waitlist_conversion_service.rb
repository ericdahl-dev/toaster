# frozen_string_literal: true

class WaitlistConversionService
  def self.call(user)
    return unless user.sign_in_count == 1

    entry = WaitlistEntry.find_by(email: user.email)
    return unless entry&.invited?

    entry.update!(status: :converted)

    Telemetry.capture(distinct_id: user.posthog_distinct_id, event: "waitlist_converted", properties: { account_id: user.account_id })
  end
end
