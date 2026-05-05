# frozen_string_literal: true

# Implementers must define (private): connections_scope, connection_id_key (JSON key for the connection id, e.g. :imap_connection_id).
module MailConnectionSync
  def create
    connection = connections_scope.find(params[:connection_id])
    InboxSyncScheduler.schedule(connection)

    render json: {
      :status => "enqueued",
      :account_id => @account.id,
      connection_id_key => connection.id
    }, status: :accepted
  rescue ActiveRecord::RecordNotFound => e
    render json: {error: e.message}, status: :not_found
  end
end
