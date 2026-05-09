# frozen_string_literal: true

class MailConnectionsController < ApplicationController
  before_action :require_authenticated_html_user!

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

  private

  def imap_params
    params.require(:mail_connection).permit(:host, :port, :username, :password, :inbox_folder, :ssl)
  end
end
