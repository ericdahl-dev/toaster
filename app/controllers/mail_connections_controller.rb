# frozen_string_literal: true

class MailConnectionsController < ApplicationController
  before_action :require_authenticated_html_user!
  before_action :set_connection, only: [:edit, :update]

  def index
    @imap_connections = current_user.account.imap_connections.order(:username)
  end

  def new
  end

  def create
    type = params.dig(:mail_connection, :type)

    if type == "imap"
      @connection = current_user.account.imap_connections.build(imap_params)
      if @connection.save
        redirect_to mail_connections_path, notice: "Mail connection added."
      else
        render :new, status: :unprocessable_content
      end
    else
      flash.now[:alert] = "Unsupported connection type."
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @venues = current_user.account.venues.order(:name)
  end

  def update
    if @connection.update(imap_update_params)
      redirect_to edit_mail_connection_path(@connection), notice: "Connection updated."
    else
      @venues = current_user.account.venues.order(:name)
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_connection
    @connection = current_user.account.imap_connections.find_by(id: params[:id])
    render plain: "Not Found", status: :not_found unless @connection
  end

  def imap_params
    params.require(:mail_connection).permit(:host, :port, :username, :password, :inbox_folder, :ssl)
  end

  def imap_update_params
    permitted = params.require(:mail_connection).permit(:host, :port, :username, :password, :inbox_folder, :ssl)
    permitted[:password].blank? ? permitted.except(:password) : permitted
  end
end
