# frozen_string_literal: true

class WaitlistMailer < ApplicationMailer
  default from: "Toaster <onboarding@resend.dev>"

  def confirmation(waitlist_entry)
    @entry = waitlist_entry
    mail(to: @entry.email, subject: "You're on the Toaster waitlist")
  end
end
