# frozen_string_literal: true

class WaitlistEntriesController < ApplicationController
  skip_before_action :verify_authenticity_token, if: :turbo_frame_request?

  def create
    @entry = WaitlistEntry.find_or_initialize_by(email: entry_params[:email].to_s.strip.downcase)
    new_record = @entry.new_record?
    @entry.assign_attributes(entry_params) if new_record

    if @entry.persisted? || @entry.save
      if new_record
        WaitlistMailer.confirmation(@entry).deliver_later
        Telemetry.capture(distinct_id: @entry.email, event: "waitlist_entry_submitted", properties: { company_name: @entry.company_name })
      end
      render :success, status: :ok
    else
      @entry.valid?
      render :form, status: :unprocessable_entity
    end
  end

  private

  def entry_params
    params.require(:waitlist_entry).permit(:email, :full_name, :company_name)
  end
end
