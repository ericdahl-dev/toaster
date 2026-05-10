# frozen_string_literal: true

class OnboardingController < ApplicationController
  before_action :require_authenticated_html_user!

  def show
  end

  def venue
  end

  def mail_connection
  end

  def complete
    current_user.account.complete_onboarding!
    redirect_to booking_requests_path
  end

  def skip
    current_user.account.complete_onboarding!
    redirect_to booking_requests_path
  end
end
