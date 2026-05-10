# frozen_string_literal: true

class Admin::AccountsController < Admin::BaseController
  def new
    @account = Account.new
    @user = User.new
  end

  def create
    @account = Account.new(account_params)
    @user = @account.users.build(user_params.merge(role: :venue_manager))

    if @account.valid? && @user.valid?
      ActiveRecord::Base.transaction do
        @account.save!
        @user.save!
      end
      Telemetry.capture(distinct_id: current_user.posthog_distinct_id, event: "admin_account_created", properties: {account_id: @account.id, account_name: @account.name, user_email: @user.email})
      redirect_to new_admin_account_path, notice: "Account and user created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def account_params
    params.require(:account).permit(:name)
  end

  def user_params
    params.require(:user).permit(:name, :email, :password)
  end
end
