# frozen_string_literal: true

# Mission Control’s controllers call `helper`; that requires ActionController::Base. This must
# be set before eager_load (CI sets eager_load): after_initialize runs too late and eager load
# hits MissionControl::Jobs::ApplicationController with a nil `_helpers` module.
MissionControl::Jobs.base_controller_class = "ActionController::Base"

Rails.application.config.after_initialize do
  if Rails.env.development? || Rails.env.test?
    MissionControl::Jobs.http_basic_auth_enabled = false
  else
    MissionControl::Jobs.http_basic_auth_enabled = true
    MissionControl::Jobs.http_basic_auth_user = ENV.fetch("MISSION_CONTROL_USERNAME", "ops")
    MissionControl::Jobs.http_basic_auth_password = ENV.fetch("MISSION_CONTROL_PASSWORD") do
      raise "MISSION_CONTROL_PASSWORD environment variable is required outside development/test"
    end
  end
end
