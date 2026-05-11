# frozen_string_literal: true

class DraftsController < ApplicationController
  before_action :require_authenticated_html_user!
  before_action :set_draft

  def approve
    @draft.update!(status: "approved")
    SendDraftJob.perform_later(@draft.id)

    Telemetry.capture(
      distinct_id: current_user.posthog_distinct_id,
      event: "draft_approved",
      properties: { draft_id: @draft.id, booking_request_id: @draft.booking_request_id }
    )

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to booking_request_path(@draft.booking_request), notice: "Draft approved — sending now." }
    end
  end

  def reject
    @draft.update!(status: "rejected")

    Telemetry.capture(
      distinct_id: current_user.posthog_distinct_id,
      event: "draft_rejected",
      properties: { draft_id: @draft.id, booking_request_id: @draft.booking_request_id }
    )

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to booking_request_path(@draft.booking_request), notice: "Draft rejected." }
    end
  end

  private

  def set_draft
    booking_request = current_user.account.booking_requests.find_by(id: params[:booking_request_id])
    @draft = booking_request&.drafts&.find_by(id: params[:id])
    render plain: "Not Found", status: :not_found unless @draft
  end
end
