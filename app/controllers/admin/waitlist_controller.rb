# frozen_string_literal: true

class Admin::WaitlistController < Admin::BaseController
  def index
    @entries = WaitlistEntry.order(created_at: :desc)
  end
end
