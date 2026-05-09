# frozen_string_literal: true

class Admin::UsersController < Admin::BaseController
  def new
    @accounts = Account.order(:name)
    @user = User.new
  end

  def create
    @accounts = Account.order(:name)
    account = Account.find(user_params[:account_id])
    @user = account.users.build(user_params.except(:account_id).merge(role: :venue_manager))

    if @user.save
      redirect_to new_admin_user_path, notice: "User created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:account_id, :name, :email, :password)
  end
end
