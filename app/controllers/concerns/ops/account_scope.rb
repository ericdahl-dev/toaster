# frozen_string_literal: true

module Ops
  module AccountScope
    extend ActiveSupport::Concern

    private

    def require_ops_account!
      account_id = params[:account_id].presence
      unless account_id
        render json: { error: "account_id is required" }, status: :bad_request
        return
      end

      @ops_account = Account.find_by(id: account_id)
      unless @ops_account
        render json: { error: "Account not found" }, status: :not_found
      end
    end

    attr_reader :ops_account
  end
end
