require "json"

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  after_discard do |job, error|
    job.send(:log_job_event, :job_discard, level: :warn, error: error)
  end

  around_perform do |job, block|
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    job.send(:log_job_event, :job_start)
    block.call
    job.send(:log_job_event, :job_success, duration_ms: job.send(:elapsed_ms, started_at))
  rescue StandardError => error
    job.send(:log_job_event, :job_failure, level: :error, duration_ms: job.send(:elapsed_ms, started_at), error: error)
    raise
  end

  private

  def elapsed_ms(started_at)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
  end

  def log_job_event(event, level: :info, duration_ms: nil, error: nil, **extra)
    payload = {
      event: event,
      job_class: self.class.name,
      job_id: job_id,
      queue: queue_name,
      executions: executions,
      arguments_summary: summarize_arguments(arguments)
    }.merge(extra)

    payload[:duration_ms] = duration_ms if duration_ms
    if error
      payload[:error_class] = error.class.name
      payload[:error_message] = error.message
    end

    Rails.logger.public_send(level, payload.to_json)
  end

  def summarize_arguments(values)
    Array(values).map { |value| summarize_argument(value) }
  end

  def summarize_argument(value)
    case value
    when Numeric, TrueClass, FalseClass, NilClass
      value
    when String
      value.length > 80 ? "#{value[0, 77]}..." : value
    when Symbol
      value.to_s
    when Array
      { type: "array", size: value.size }
    when Hash
      { type: "hash", keys: value.keys.map(&:to_s).first(5) }
    else
      value.class.name
    end
  end
end
