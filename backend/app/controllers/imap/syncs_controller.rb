module Imap
  class SyncsController < AccountScopedController
    def create
      connection = @account.imap_connections.find(params[:connection_id])
      InboxSyncScheduler.schedule(connection)

      render json: {
        status: "enqueued",
        account_id: @account.id,
        imap_connection_id: connection.id
      }, status: :accepted
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    end
  end
end
