# frozen_string_literal: true

class ExpireWaitlistInvitesJob < ApplicationJob
  queue_as :default

  def perform
    cutoff = Devise.reset_password_within.ago

    expired_count = WaitlistEntry.invited.where("invited_at <= ?", cutoff).update_all(status: :expired)

    log_job_event(:waitlist_invites_expired, expired_count: expired_count)
  end
end
