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
end
