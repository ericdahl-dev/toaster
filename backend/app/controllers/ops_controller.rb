class OpsController < ApplicationController
  # Queue/system observability endpoints for operators.
  # All responses are scoped to the last 24 hours unless otherwise noted.
  skip_forgery_protection
  include Ops::RequireToken

  LOOKBACK = 24.hours

  def index
    render json: {
      queued_jobs: GoodJob::Job.where(finished_at: nil).count,
      failed_jobs: GoodJob::Job.where.not(error: nil).where.not(finished_at: nil).count,
      pending_drafts: Draft.pending_review.count,
      approved_drafts: Draft.approved.count
    }
  end

  def failed_jobs
    failures = GoodJob::Job
      .where.not(error: nil)
      .where.not(finished_at: nil)
      .order(finished_at: :desc)
      .limit(100)
      .map do |job|
        {
          id: job.id,
          job_id: job.id,
          class_name: job.job_class,
          queue_name: job.queue_name,
          error: job.error,
          failed_at: job.finished_at
        }
      end
    render json: {failed_jobs: failures}
  end

  def ai_runs
    runs = AiRun
      .where(created_at: LOOKBACK.ago..)
      .order(created_at: :desc)
      .limit(100)
      .map do |run|
        {
          id: run.id,
          account_id: run.account_id,
          booking_request_id: run.booking_request_id,
          llm_model: run.llm_model,
          input_tokens: run.input_tokens,
          output_tokens: run.output_tokens,
          created_at: run.created_at
        }
      end
    render json: {ai_runs: runs}
  end

  def retry_failed_job
    job = GoodJob::Job.find(params[:id])
    job.retry_job
    render json: {status: "retried", job_id: job.id}
  rescue ActiveRecord::RecordNotFound
    render json: {error: "Failed job not found"}, status: :not_found
  end

  def retry_draft
    draft = Draft.find(params[:id])
    unless draft.approved?
      return render json: {error: "Draft is not in approved state"}, status: :unprocessable_entity
    end
    PushDraftJob.perform_later(draft.id)
    render json: {status: "enqueued", draft_id: draft.id}
  rescue ActiveRecord::RecordNotFound
    render json: {error: "Draft not found"}, status: :not_found
  end
end
