# frozen_string_literal: true

class BookingRequestsController < ApplicationController
  before_action :require_authenticated_html_user!
  before_action :set_booking_request, only: [ :show, :transition, :archive, :unarchive ]

  def index
    scope = current_user.account.booking_requests
    scope = params[:show_archived] == "1" ? scope.archived : scope.active

    @booking_requests = scope
      .includes(:contact, :venue, :conversation_thread, :source_inbox_message, :messages, :drafts, :tasks)
      .order(updated_at: :desc)
    @show_archived = params[:show_archived] == "1"

    booking_request_ids = @booking_requests.map(&:id)
    @pending_review_draft_ids = Draft.where(booking_request_id: booking_request_ids, status: :pending_review)
      .pluck(:booking_request_id)
      .to_set
    @open_task_ids = Task.where(booking_request_id: booking_request_ids, status: :open)
      .pluck(:booking_request_id)
      .to_set
  end

  def show
  end

  def transition
    to = params[:to].to_s
    BookingRequests::Transition.call(booking_request: @booking_request, to: to, metadata: { distinct_id: current_user.posthog_distinct_id })
    redirect_to booking_request_path(@booking_request), notice: "Status updated to #{to}."
  rescue BookingRequests::Transition::InvalidTransition => e
    redirect_to booking_request_path(@booking_request), alert: e.message
  end

  def archive
    BookingRequests::Archive.call(
      booking_request: @booking_request,
      metadata: { distinct_id: current_user.posthog_distinct_id }
    )
    redirect_to booking_requests_path, notice: "Booking request archived."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to booking_request_path(@booking_request), alert: e.record.errors.full_messages.to_sentence
  end

  def unarchive
    BookingRequests::Unarchive.call(
      booking_request: @booking_request,
      metadata: { distinct_id: current_user.posthog_distinct_id, source: "manual" }
    )
    redirect_to booking_request_path(@booking_request), notice: "Booking request restored."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to booking_request_path(@booking_request), alert: e.record.errors.full_messages.to_sentence
  end

  private

  def archive_confirm_message
    if @pending_review_draft_ids.include?(@booking_request.id) || @open_task_ids.include?(@booking_request.id)
      "Archive anyway? This request still has an open draft or review task."
    else
      "Archive this booking request? It will be hidden from the main list."
    end
  end
  helper_method :archive_confirm_message

  def set_booking_request
    @booking_request = current_user.account.booking_requests
      .includes(:source_inbox_message, :messages, :drafts, :tasks)
      .find_by(id: params[:id])

    unless @booking_request
      render plain: "Not Found", status: :not_found
      return
    end

    booking_request_ids = [ @booking_request.id ]
    @pending_review_draft_ids = Draft.where(booking_request_id: booking_request_ids, status: :pending_review)
      .pluck(:booking_request_id)
      .to_set
    @open_task_ids = Task.where(booking_request_id: booking_request_ids, status: :open)
      .pluck(:booking_request_id)
      .to_set
  end
end
