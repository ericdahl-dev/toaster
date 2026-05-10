# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  protect_from_forgery with: :exception

  helper_method :current_user

  rescue_from Pundit::NotAuthorizedError do
    redirect_to root_path, alert: "You are not authorized to perform that action."
  end

  protected

  def after_sign_in_path_for(resource)
    WaitlistConversionService.call(resource)

    Telemetry.identify(distinct_id: resource.posthog_distinct_id, properties: resource.posthog_properties)
    Telemetry.capture(distinct_id: resource.posthog_distinct_id, event: "user_signed_in", properties: { sign_in_count: resource.sign_in_count })

    resource.account.onboarded? ? booking_requests_path : onboarding_path
  end
end
