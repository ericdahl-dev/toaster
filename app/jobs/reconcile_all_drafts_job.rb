class ReconcileAllDraftsJob < ApplicationJob
  queue_as :mailers

  def perform
    enqueued_count = 0

    Draft.pending_review.where.not(imap_draft_uid: nil).find_each do |draft|
      ReconcileDraftJob.perform_later(draft.id)
      enqueued_count += 1
    end

    log_job_event(:reconcile_drafts_fanout_enqueued, enqueued_count: enqueued_count)
  end
end
