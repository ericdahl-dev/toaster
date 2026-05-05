# frozen_string_literal: true

# Shared per-connection enqueue behaviour for inbox connection sync controllers.
#
# Including controllers must define (as private methods):
#   - connections_scope   → account-scoped ActiveRecord relation for the provider's model
#   - connection_id_key   → Symbol used as the connection-id key in the JSON response
#                           (e.g. :imap_connection_id or :agentmail_connection_id)
#
# Authorization (cross-account guard) is inherited from AccountScopedController.
# Provider-specific job dispatch is handled by InboxSyncScheduler, which
# resolves the correct job class from the connection type.
module MailConnectionSync
  def create
    connection = connections_scope.find(params[:connection_id])
    InboxSyncScheduler.schedule(connection)

    render json: {
      status: "enqueued",
      account_id: @account.id,
      connection_id_key => connection.id
    }, status: :accepted
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end
end
