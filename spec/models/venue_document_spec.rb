# frozen_string_literal: true

require "rails_helper"

RSpec.describe VenueDocument, type: :model do
  let(:venue) { create(:venue) }

  describe "validations" do
    it "is valid with venue and filename" do
      doc = build(:venue_document, venue: venue)
      expect(doc).to be_valid
    end

    it "requires source_filename" do
      doc = build(:venue_document, venue: venue, source_filename: "")
      expect(doc).not_to be_valid
    end
  end

  describe "status enum" do
    it "defaults to pending" do
      doc = create(:venue_document, venue: venue)
      expect(doc).to be_pending
    end

    it "can transition to processing" do
      doc = create(:venue_document, venue: venue)
      doc.processing!
      expect(doc).to be_processing
    end

    it "can transition to ready" do
      doc = create(:venue_document, venue: venue, status: :processing)
      doc.ready!
      expect(doc).to be_ready
    end

    it "can transition to failed" do
      doc = create(:venue_document, venue: venue, status: :processing)
      doc.failed!
      expect(doc).to be_failed
    end
  end

  describe "associations" do
    it "belongs to a venue" do
      doc = build(:venue_document, venue: venue)
      expect(doc.venue).to eq(venue)
    end

    it "destroys chunks when destroyed" do
      doc = create(:venue_document, venue: venue)
      create(:venue_chunk, venue_document: doc)
      expect { doc.destroy }.to change(VenueChunk, :count).by(-1)
    end
  end
end
