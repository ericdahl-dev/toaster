# frozen_string_literal: true

# Implementers must define (private): connections_scope, connection_params, connection_json(connection).
#
# Sync checkpoints (last_synced_uid / last_synced_at) belong on the provider model and InboxIngestion adapters—not this concern.
module MailConnections
  extend ActiveSupport::Concern

  included do
    before_action :set_connection, only: [:show, :update, :destroy]
  end

  def index
    connections = connections_scope.order(:created_at)
    render json: {connections: connections.map { |c| connection_json(c) }}
  end

  def show
    render json: {connection: connection_json(@connection)}
  end

  def create
    connection = connections_scope.build(connection_params)
    if connection.save
      InboxSyncScheduler.schedule(connection)
      render json: {connection: connection_json(connection)}, status: :created
    else
      render json: {errors: connection.errors.full_messages}, status: :unprocessable_entity
    end
  end

  def update
    if @connection.update(connection_params)
      render json: {connection: connection_json(@connection)}
    else
      render json: {errors: @connection.errors.full_messages}, status: :unprocessable_entity
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
    render json: {error: "Connection not found"}, status: :not_found
  end
end
