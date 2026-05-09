# frozen_string_literal: true

class WaitlistEntriesController < ApplicationController
  skip_before_action :verify_authenticity_token, if: :turbo_frame_request?

  def create
    @entry = WaitlistEntry.find_or_initialize_by(email: entry_params[:email].to_s.strip.downcase)

    if @entry.persisted? || @entry.save
      render :success, status: :ok
    else
      @entry = WaitlistEntry.new(entry_params)
      @entry.valid?
      render :form, status: :unprocessable_entity
    end
  end

  private

  def entry_params
    params.require(:waitlist_entry).permit(:email)
  end
end
