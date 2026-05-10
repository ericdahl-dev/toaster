# frozen_string_literal: true

class SessionsController < Devise::SessionsController
  layout "application"

  def new
    redirect_to root_path, notice: "Already signed in." if current_user
    super
  end

  protected

  def after_sign_in_path_for(resource)
    WaitlistConversionService.call(resource)

    Telemetry.identify(distinct_id: resource.posthog_distinct_id, properties: resource.posthog_properties)
    Telemetry.capture(distinct_id: resource.posthog_distinct_id, event: "user_signed_in", properties: {sign_in_count: resource.sign_in_count})

    resource.account.onboarded? ? booking_requests_path : onboarding_path
  end

  def after_sign_out_path_for(_resource_or_scope)
    login_path
  end
end
