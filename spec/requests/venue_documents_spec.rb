# frozen_string_literal: true

require "rails_helper"

RSpec.describe "VenueDocuments", type: :request do
  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }
  let!(:venue) { create(:venue, account: account) }

  describe "POST /venues/:venue_id/documents" do
    let(:file) { fixture_file_upload("event_guide.txt", "text/plain") }

    context "when signed in" do
      before { sign_in user }

      it "creates a VenueDocument and enqueues ingestion" do
        expect {
          post venue_documents_path(venue), params: { document: { file: file } }
        }.to change(VenueDocument, :count).by(1)
          .and have_enqueued_job(IngestVenueDocumentJob)

        expect(response).to redirect_to(edit_venue_path(venue))
      end

      it "sets source_filename from uploaded file" do
        post venue_documents_path(venue), params: { document: { file: file } }

        expect(VenueDocument.last.source_filename).to eq("event_guide.txt")
      end

      it "rejects upload for another account's venue" do
        other_venue = create(:venue)
        post venue_documents_path(other_venue), params: { document: { file: file } }
        expect(response).to have_http_status(:not_found)
      end

      it "sanitizes path-traversal filenames and lands file inside tmp/venue_documents/" do
        traversal_file = fixture_file_upload("event_guide.txt", "text/plain")
        traversal_file.instance_variable_set(:@original_filename, "../../../etc/passwd")

        expect {
          post venue_documents_path(venue), params: { document: { file: traversal_file } }
        }.to change(VenueDocument, :count).by(1)

        doc = VenueDocument.last
        safe_root = Rails.root.join("tmp", "venue_documents").to_s
        resolved = File.expand_path(doc.file_path)
        expect(resolved).to start_with(safe_root)
        expect(doc.file_path).not_to include("..")
      end

      it "returns unprocessable when no file given" do
        post venue_documents_path(venue), params: { document: { file: nil } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when signed out" do
      it "redirects to login" do
        post venue_documents_path(venue), params: { document: { file: file } }
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/login")
      end
    end
  end

  describe "DELETE /venues/:venue_id/documents/:id" do
    let!(:doc) { create(:venue_document, venue: venue) }

    context "when signed in" do
      before { sign_in user }

      it "destroys the document and redirects" do
        expect {
          delete venue_document_path(venue, doc)
        }.to change(VenueDocument, :count).by(-1)

        expect(response).to redirect_to(edit_venue_path(venue))
      end
    end
  end

  describe "PATCH /venues/:venue_id/documents/:id" do
    let(:new_file) { fixture_file_upload("event_guide.txt", "text/plain") }
    let!(:doc) { create(:venue_document, venue: venue, status: :ready) }

    context "when signed in" do
      before { sign_in user }

      it "updates filename, resets to pending, clears error, deletes chunks, re-enqueues ingestion" do
        doc.update!(error_message: "old error")
        create(:venue_chunk, venue_document: doc)

        expect {
          patch venue_document_path(venue, doc), params: { document: { file: new_file } }
        }.to have_enqueued_job(IngestVenueDocumentJob).with(doc.id)

        doc.reload
        expect(doc.source_filename).to eq("event_guide.txt")
        expect(doc.status).to eq("pending")
        expect(doc.error_message).to be_nil
        expect(doc.venue_chunks.count).to eq(0)
        expect(response).to redirect_to(edit_venue_path(venue))
      end

      it "returns unprocessable when no file given" do
        patch venue_document_path(venue, doc), params: { document: { file: nil } }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "rejects replace for another account's venue" do
        other_venue = create(:venue)
        patch venue_document_path(other_venue, doc), params: { document: { file: new_file } }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed out" do
      it "redirects to login" do
        patch venue_document_path(venue, doc), params: { document: { file: new_file } }
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/login")
      end
    end
  end
end
