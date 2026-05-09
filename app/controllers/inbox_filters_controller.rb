# frozen_string_literal: true

class InboxFiltersController < ApplicationController
  before_action :require_authenticated_html_user!
  before_action :set_connection

  def create
    position = @connection.inbox_filters.count
    filter = @connection.inbox_filters.build(
      keyword: params[:inbox_filter][:keyword],
      venue_id: params[:inbox_filter][:venue_id],
      position: position
    )
    if filter.save
      redirect_to edit_mail_connection_path(@connection), notice: "Filter added."
    else
      redirect_to edit_mail_connection_path(@connection), alert: filter.errors.full_messages.join(", ")
    end
  end

  def destroy
    filter = @connection.inbox_filters.find_by(id: params[:id])
    filter&.destroy!
    redirect_to edit_mail_connection_path(@connection), notice: "Filter removed."
  end

  private

  def set_connection
    @connection = current_account.imap_connections.find_by(id: params[:mail_connection_id])
    render plain: "Not Found", status: :not_found unless @connection
  end
end
