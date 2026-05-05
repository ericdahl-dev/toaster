# frozen_string_literal: true

class UsersController < AccountScopedController
  before_action :set_user, only: [ :show, :update, :destroy ]
  before_action :prevent_self_removal, only: [ :destroy ]

  def index
    users = @account.users.order(:name)
    render json: { users: users.map { |u| user_json(u) } }
  end

  def show
    render json: { user: user_json(@user) }
  end

  def create
    user = @account.users.build(user_params)
    if user.save
      render json: { user: user_json(user) }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @user.update(user_params)
      render json: { user: user_json(@user) }
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    head :no_content
  end

  private

  def set_user
    @user = @account.users.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "User not found" }, status: :not_found
  end

  def prevent_self_removal
    if @user.id == current_user.id
      render json: { error: "You cannot remove your own account" }, status: :unprocessable_entity
    end
  end

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end

  def user_json(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end
end
