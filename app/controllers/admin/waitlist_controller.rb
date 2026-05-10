# frozen_string_literal: true

class Admin::WaitlistController < Admin::BaseController
  before_action :set_entry, only: [:invite, :resend_invite]

  def index
    @entries = WaitlistEntry.order(created_at: :desc)
  end

  def invite
    if request.get?
      @account = Account.new(name: @entry.company_name)
      @user = User.new(name: @entry.full_name, email: @entry.email)
    else
      existing_user = User.find_by(email: @entry.email)

      if existing_user
        raw, hashed = Devise.token_generator.generate(User, :reset_password_token)
        existing_user.update_columns(reset_password_token: hashed, reset_password_sent_at: Time.current)
        WaitlistMailer.invite(@entry, existing_user, raw).deliver_later
        @entry.update!(status: :invited, invited_at: Time.current)
        redirect_to admin_waitlist_index_path, notice: "Invite resent to #{@entry.email}."
        return
      end

      @account = Account.new(account_params)
      @user = User.new(user_params.merge(role: :venue_manager, password: SecureRandom.hex(24)))
      @user.account = @account

      if @account.valid? && @user.valid?
        ActiveRecord::Base.transaction do
          @account.save!
          @user.save!

          raw, hashed = Devise.token_generator.generate(User, :reset_password_token)
          @user.update_columns(
            reset_password_token: hashed,
            reset_password_sent_at: Time.current
          )

          WaitlistMailer.invite(@entry, @user, raw).deliver_later

          @entry.update!(status: :invited, invited_at: Time.current)
        end

        redirect_to admin_waitlist_index_path, notice: "Invite sent to #{@entry.email}."
      else
        render :invite, status: :unprocessable_entity
      end
    end
  end

  def resend_invite
    user = User.find_by(email: @entry.email)

    if user.nil?
      redirect_to admin_waitlist_index_path, alert: "No user found for #{@entry.email} — use Invite instead."
      return
    end

    raw, hashed = Devise.token_generator.generate(User, :reset_password_token)
    user.update_columns(reset_password_token: hashed, reset_password_sent_at: Time.current)
    WaitlistMailer.invite(@entry, user, raw).deliver_later
    @entry.update!(status: :invited, invited_at: Time.current)

    redirect_to admin_waitlist_index_path, notice: "Invite resent to #{@entry.email}."
  end

  private

  def set_entry
    @entry = WaitlistEntry.find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name)
  end

  def user_params
    params.require(:user).permit(:name, :email)
  end
end
