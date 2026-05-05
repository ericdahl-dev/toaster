# frozen_string_literal: true

module Ops
  module RequireToken
    extend ActiveSupport::Concern

    included do
      before_action :require_ops_auth!
    end

    private

    def require_ops_auth!
      token = ENV["OPS_AUTH_TOKEN"].presence
      return render json: {error: "Unauthorized"}, status: :unauthorized unless token

      provided = request.headers["X-Ops-Token"]
      return if ActiveSupport::SecurityUtils.secure_compare(provided.to_s, token)

      render json: {error: "Unauthorized"}, status: :unauthorized
    end
  end
end
