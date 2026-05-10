# frozen_string_literal: true

class InboxThreadsController < ApplicationController
  before_action :require_authenticated_html_user!
  before_action :set_thread, only: [ :show ]

  def index
    @threads = current_user.account.conversation_threads
      .includes(:contact, :booking_requests)
      .order(updated_at: :desc)
  end

  def show
  end

  private

  def set_thread
    @thread = current_user.account.conversation_threads
      .includes(:contact, :messages, booking_requests: [ :source_inbox_message, :drafts ])
      .find_by(id: params[:id])
    render plain: "Not Found", status: :not_found unless @thread
  end
end
