module Imap
  class SyncsController < ApplicationController
    def create
      account = Account.find(params[:account_id])
      connection = account.imap_connections.find(params[:connection_id])
      SyncImapJob.perform_later(connection.id)

      render json: {
        status: "enqueued",
        account_id: account.id,
        imap_connection_id: connection.id
      }, status: :accepted
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    end
  end
end
