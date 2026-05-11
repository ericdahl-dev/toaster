class ConsolidateDuplicateBookingRequestsPerThread < ActiveRecord::Migration[8.1]
  def up
    # For each thread with multiple booking requests, keep the oldest (canonical) and
    # reassign all child records from the duplicates to it, then destroy the duplicates.
    duplicate_thread_ids = execute(<<~SQL).map { |r| r["conversation_thread_id"] }
      SELECT conversation_thread_id
      FROM booking_requests
      GROUP BY conversation_thread_id
      HAVING COUNT(*) > 1
    SQL

    duplicate_thread_ids.each do |thread_id|
      brs = BookingRequest.where(conversation_thread_id: thread_id).order(:created_at)
      canonical = brs.first
      duplicates = brs[1..]

      duplicate_ids = duplicates.map(&:id)

      Message.where(booking_request_id: duplicate_ids).update_all(booking_request_id: canonical.id)
      Draft.where(booking_request_id: duplicate_ids).update_all(booking_request_id: canonical.id)
      Task.where(booking_request_id: duplicate_ids).update_all(booking_request_id: canonical.id)
      AiRun.where(booking_request_id: duplicate_ids).update_all(booking_request_id: canonical.id)
      EventLog.where(subject_type: "BookingRequest", subject_id: duplicate_ids)
              .update_all(subject_id: canonical.id)

      duplicates.each(&:destroy!)
    end
  end

  def down
    # Not reversible — data consolidation cannot be undone
    raise ActiveRecord::IrreversibleMigration
  end
end
