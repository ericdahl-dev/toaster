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
    redirect_to edit_venue_path(@venue), notice: "Document uploaded — ingestion started."
  rescue => e
    render plain: e.message, status: :unprocessable_content
  end

  def destroy
    doc = @venue.venue_documents.find(params[:id])
    FileUtils.rm_f(doc.file_path) if doc.file_path.present?
    doc.destroy!
    redirect_to edit_venue_path(@venue), notice: "Document removed."
  end

  private

  def set_venue
    @venue = current_user.account.venues.find_by(id: params[:venue_id])
    render plain: "Not Found", status: :not_found unless @venue
  end
end
