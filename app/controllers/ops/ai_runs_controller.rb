# frozen_string_literal: true

module Ops
  class AiRunsController < ApplicationController
    skip_forgery_protection
    include Ops::RequireToken

    def index
      scope = AiRun.order(created_at: :desc).limit(200)
      scope = scope.where(run_type: params[:run_type]) if params[:run_type].present?
      scope = scope.where(booking_request_id: params[:booking_request_id]) if params[:booking_request_id].present?

      render json: {
        ai_runs: scope.map { |run| run_summary(run) }
      }
    end

    def show
      run = AiRun.find(params[:id])
      render json: {ai_run: run_detail(run)}
    rescue ActiveRecord::RecordNotFound
      render json: {error: "AiRun not found"}, status: :not_found
    end

    private

    def run_summary(run)
      {
        id: run.id,
        account_id: run.account_id,
        booking_request_id: run.booking_request_id,
        run_type: run.run_type,
        llm_model: run.llm_model,
        prompt_version: run.prompt_version,
        latency_ms: run.latency_ms,
        rag_chunk_count: run.rag_chunk_count,
        created_at: run.created_at
      }
    end

    def run_detail(run)
      run_summary(run).merge(
        prompt: run.prompt,
        response: run.response
      )
    end
  end
end
