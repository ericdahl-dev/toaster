# frozen_string_literal: true

# Shared CRUD behaviour for provider-specific inbox connection controllers.
#
# Including controllers must define (as private methods):
#   - connections_scope    → account-scoped ActiveRecord relation for the provider's model
#   - connection_params    → strong-parameter hash for create/update
#   - connection_json(c)   → Hash representation of a connection (omit credentials)
#
# What must stay provider-specific:
#   - connection_params  – each provider has different required fields
#   - connection_json    – each provider exposes different attributes
#   - connections_scope  – each provider owns a different model/association
#
# Checkpoint semantics (e.g. last_synced_uid, last_synced_at) live in the
# provider's model and ingestion adapters – see InboxIngestion adapters and
# CONTEXT.md. They must not be managed here.
module MailConnections
  extend ActiveSupport::Concern

  included do
    before_action :set_connection, only: [ :show, :update, :destroy ]
  end

  def index
    connections = connections_scope.order(:created_at)
    render json: { connections: connections.map { |c| connection_json(c) } }
  end

  def show
    render json: { connection: connection_json(@connection) }
  end

  def create
    connection = connections_scope.build(connection_params)
    if connection.save
      InboxSyncScheduler.schedule(connection)
      render json: { connection: connection_json(connection) }, status: :created
    else
      render json: { errors: connection.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @connection.update(connection_params)
      render json: { connection: connection_json(@connection) }
    else
      render json: { errors: @connection.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @connection.destroy
    head :no_content
  end

  private

  def set_connection
    @connection = connections_scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Connection not found" }, status: :not_found
  end
end
