# frozen_string_literal: true

class Admin::UsersController < Admin::BaseController
  def new
    @accounts = Account.order(:name)
    @user = User.new
  end

  def create
    @accounts = Account.order(:name)
    account = Account.find(params.require(:user).fetch(:account_id))
    @user = account.users.build(user_params.merge(role: :venue_manager))

    if @user.save
      redirect_to new_admin_user_path, notice: "User created successfully."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password)
  end
end
