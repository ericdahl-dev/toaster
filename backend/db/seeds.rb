# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

if Rails.env.development?
  # Matches frontend default NEXT_PUBLIC_TOASTER_ACCOUNT_ID / TOASTER_ACCOUNT_ID ("1").
  account = Account.find_or_initialize_by(id: 1)
  if account.new_record?
    account.name = "Local dev"
    account.save!
    ActiveRecord::Base.connection.reset_pk_sequence!("accounts")
  end

  dev_password = ENV.fetch("TOASTER_DEV_USER_PASSWORD", "password123")
  user = User.find_or_initialize_by(email: "dev@toaster.local")
  user.account = account
  user.name = "Local dev user"
  user.password = dev_password
  user.password_confirmation = dev_password
  user.save!
end
