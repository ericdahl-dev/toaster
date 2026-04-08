Rails.application.config.after_initialize do
  MissionControl::Jobs.base_controller_class = "ActionController::Base"

  if Rails.env.production?
    MissionControl::Jobs.http_basic_auth_enabled = true
    MissionControl::Jobs.http_basic_auth_user = ENV.fetch("MISSION_CONTROL_USERNAME", "ops")
    MissionControl::Jobs.http_basic_auth_password = ENV.fetch("MISSION_CONTROL_PASSWORD") do
      raise "MISSION_CONTROL_PASSWORD environment variable is required in production"
    end
  else
    MissionControl::Jobs.http_basic_auth_enabled = false
  end
end
