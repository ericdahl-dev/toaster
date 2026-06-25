# frozen_string_literal: true

class AddUniquePendingReviewDraftPerBookingRequest < ActiveRecord::Migration[8.0]
  def change
    add_index :drafts, :booking_request_id,
      unique: true,
      where: "status = 'pending_review'",
      name: "index_drafts_on_booking_request_id_pending_review"
  end
end
