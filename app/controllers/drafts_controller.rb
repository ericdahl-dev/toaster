# frozen_string_literal: true

class DraftsController < ApplicationController
  before_action :require_authenticated_html_user!
  before_action :set_draft

  def approve
    SendDraftJob.perform_later(@draft.id)
    redirect_to booking_request_path(@draft.booking_request), notice: "Draft approved — sending now."
  end

  def reject
    @draft.update!(status: "rejected")
    redirect_to booking_request_path(@draft.booking_request), notice: "Draft rejected."
  end

  private

  def set_draft
    booking_request = current_account.booking_requests.find_by(id: params[:booking_request_id])
    @draft = booking_request&.drafts&.find_by(id: params[:id])
    render plain: "Not Found", status: :not_found unless @draft
  end
end
