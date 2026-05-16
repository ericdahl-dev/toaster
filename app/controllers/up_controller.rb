class UpController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def show
    checks = {
      database: database_check
    }

    healthy = checks.values.all? { |c| c[:ok] }
    status = healthy ? :ok : :service_unavailable

    render json: { status: healthy ? "ok" : "degraded", service: "toaster-backend", checks: checks }, status: status
  end

  private

  def database_check
    ActiveRecord::Base.connection.execute("SELECT 1")
    { ok: true }
  rescue => e
    { ok: false, error: e.message }
  end
end
