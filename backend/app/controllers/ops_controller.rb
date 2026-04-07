class OpsController < ApplicationController
  # Queue/system observability endpoints for operators.
  # All responses are scoped to the last 24 hours unless otherwise noted.

  LOOKBACK = 24.hours

  def index
    render json: {
      queued_jobs: SolidQueue::Job.where(finished_at: nil).count,
      failed_jobs: SolidQueue::FailedExecution.count,
      unprocessed_webhook_events: GmailWebhookEvent.unprocessed.count,
      active_gmail_connections: GmailConnection.where(active: true).count,
      pending_drafts: Draft.pending_review.count,
      approved_drafts: Draft.approved.count
    }
  end

  def gmail_connections
    connections = GmailConnection.all.map do |conn|
      {
        id: conn.id,
        account_id: conn.account_id,
        email: conn.email,
        active: conn.active,
        created_at: conn.created_at
      }
    end
    render json: {gmail_connections: connections}
  end

  def webhook_events
    events = GmailWebhookEvent
      .order(created_at: :desc)
      .limit(100)
      .map do |ev|
        {
          id: ev.id,
          account_id: ev.account_id,
          gmail_history_id: ev.gmail_history_id,
          processed: ev.processed?,
          processed_at: ev.processed_at,
          created_at: ev.created_at
        }
      end
    render json: {webhook_events: events}
  end

  def failed_jobs
    failures = SolidQueue::FailedExecution
      .includes(:job)
      .order(created_at: :desc)
      .limit(100)
      .map do |fe|
        {
          id: fe.id,
          job_id: fe.job_id,
          class_name: fe.job.class_name,
          queue_name: fe.job.queue_name,
          error: fe.error,
          failed_at: fe.created_at
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
    fe = SolidQueue::FailedExecution.find(params[:id])
    fe.retry
    render json: {status: "retried", job_id: fe.job_id}
  rescue ActiveRecord::RecordNotFound
    render json: {error: "Failed job not found"}, status: :not_found
  end

  def retry_webhook_event
    event = GmailWebhookEvent.find(params[:id])
    event.update!(processed_at: nil)
    ProcessGmailWebhookEventJob.perform_later(event.id)
    render json: {status: "enqueued", webhook_event_id: event.id}
  rescue ActiveRecord::RecordNotFound
    render json: {error: "Webhook event not found"}, status: :not_found
  end

  def retry_draft
    draft = Draft.find(params[:id])
    unless draft.approved?
      return render json: {error: "Draft is not in approved state"}, status: :unprocessable_entity
    end
    SendDraftJob.perform_later(draft.id)
    render json: {status: "enqueued", draft_id: draft.id}
  rescue ActiveRecord::RecordNotFound
    render json: {error: "Draft not found"}, status: :not_found
  end
end
