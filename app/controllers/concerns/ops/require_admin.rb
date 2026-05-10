# frozen_string_literal: true

module Ops
  module RequireAdmin
    extend ActiveSupport::Concern

    included do
      before_action :require_ops_admin!
    end

    private

    def require_ops_admin!
      authenticate_user!
      return if current_user&.admin?

      redirect_to root_path, status: :see_other
    end
  end
end
