module AgentMailbox
  class SyncsController < ApplicationController
    def create
      account = Account.find(params[:account_id])
      SyncAgentMailboxJob.perform_later(account.id)

      render json: {
        status: "enqueued",
        account_id: account.id
      }, status: :accepted
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Account not found" }, status: :not_found
    end
  end
end
