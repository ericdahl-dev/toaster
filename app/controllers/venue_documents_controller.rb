# frozen_string_literal: true

class VenueDocumentsController < ApplicationController
  before_action :require_authenticated_html_user!
  before_action :set_venue

  def create
    file = params.dig(:document, :file)

    unless file.present?
      render plain: "No file provided", status: :unprocessable_content
      return
    end

    dest_dir = Rails.root.join("tmp", "venue_documents")
    FileUtils.mkdir_p(dest_dir)
    dest_path = dest_dir.join("#{SecureRandom.hex(8)}_#{file.original_filename}")
    FileUtils.cp(file.tempfile.path, dest_path)

    doc = @venue.venue_documents.create!(
      source_filename: file.original_filename,
      file_path: dest_path.to_s
    )

    IngestVenueDocumentJob.perform_later(doc.id)

    Telemetry.capture(
      distinct_id: current_user.posthog_distinct_id,
      event: "venue_document_uploaded",
      properties: { venue_id: @venue.id, filename: file.original_filename }
    )

    redirect_to edit_venue_path(@venue), notice: "Document uploaded — ingestion started."
  rescue => e
    Telemetry.capture_exception(e, current_user.posthog_distinct_id)
    render plain: e.message, status: :unprocessable_content
  end

  def update
    doc = @venue.venue_documents.find(params[:id])
    file = params.dig(:document, :file)

    unless file.present?
      render plain: "No file provided", status: :unprocessable_content
      return
    end

    if doc.file_path.present?
      safe_root = Rails.root.join("tmp", "venue_documents").to_s
      resolved = File.expand_path(doc.file_path)
      FileUtils.rm_f(resolved) if resolved.start_with?(safe_root)
    end

    dest_dir = Rails.root.join("tmp", "venue_documents")
    FileUtils.mkdir_p(dest_dir)
    dest_path = dest_dir.join("#{SecureRandom.hex(8)}_#{file.original_filename}")
    FileUtils.cp(file.tempfile.path, dest_path)

    doc.venue_chunks.delete_all
    doc.update!(
      source_filename: file.original_filename,
      file_path: dest_path.to_s,
      status: :pending,
      error_message: nil,
      chunk_count: nil
    )

    IngestVenueDocumentJob.perform_later(doc.id)

    Telemetry.capture(
      distinct_id: current_user.posthog_distinct_id,
      event: "venue_document_replaced",
      properties: { venue_id: @venue.id, filename: file.original_filename }
    )

    redirect_to edit_venue_path(@venue), notice: "Document replaced — ingestion started."
  rescue => e
    Telemetry.capture_exception(e, current_user.posthog_distinct_id)
    render plain: e.message, status: :unprocessable_content
  end

  def destroy
    doc = @venue.venue_documents.find(params[:id])
    if doc.file_path.present?
      safe_root = Rails.root.join("tmp", "venue_documents").to_s
      resolved = File.expand_path(doc.file_path)
      FileUtils.rm_f(resolved) if resolved.start_with?(safe_root)
    end
    doc.destroy!
    redirect_to edit_venue_path(@venue), notice: "Document removed."
  end

  private

  def set_venue
    @venue = current_user.account.venues.find_by(id: params[:venue_id])
    render plain: "Not Found", status: :not_found unless @venue
  end
end
