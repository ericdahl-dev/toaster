# frozen_string_literal: true

class WaitlistMailer < ApplicationMailer
  default from: "Toaster <toaster@ericdahl.dev>"

  def confirmation(waitlist_entry)
    @entry = waitlist_entry
    mail(to: @entry.email, subject: "You're on the Toaster waitlist")
  end

  def invite(waitlist_entry, user, raw_token)
    @entry = waitlist_entry
    @user = user
    @reset_url = edit_user_password_url(@user, reset_password_token: raw_token)
    mail(to: @entry.email, subject: "Your Toaster account is ready")
  end
end
