# frozen_string_literal: true

class OpsController < ApplicationController
  skip_forgery_protection
  include Ops::RequireToken
  include Ops::RequireAdmin

  skip_before_action :require_ops_admin!, only: [ :index, :failed_jobs, :retry_failed_job, :retry_draft ]

  def index
    @queued_jobs = GoodJob::Job.where(finished_at: nil).count
    @failed_jobs_count = GoodJob::Job.where.not(error: nil).where.not(finished_at: nil).count
    @pending_drafts = Draft.pending_review.count
    @approved_drafts = Draft.approved.count
    @recent_ai_runs = AiRun.order(created_at: :desc).limit(10)
    @recent_failed_jobs = GoodJob::Job
      .where.not(error: nil)
      .where.not(finished_at: nil)
      .order(finished_at: :desc)
      .limit(5)
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
    render json: { failed_jobs: failures }
  end

  def retry_failed_job
    job = GoodJob::Job.find(params[:id])
    job.retry_job
    render json: { status: "retried", job_id: job.id }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Failed job not found" }, status: :not_found
  end

  def retry_draft
    draft = Draft.find(params[:id])
    unless draft.approved?
      return render json: { error: "Draft is not in approved state" }, status: :unprocessable_content
    end
    PushDraftJob.perform_later(draft.id)
    render json: { status: "enqueued", draft_id: draft.id }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Draft not found" }, status: :not_found
  end
end
