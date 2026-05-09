# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

if Rails.env.production?
  # Create the initial account if none exists. Configure via env vars before first deploy.
  # TOASTER_SEED_ACCOUNT_NAME — account display name (default: "Toaster")
  # TOASTER_ADMIN_EMAIL / TOASTER_ADMIN_PASSWORD / TOASTER_ADMIN_NAME — bootstrap admin user (optional)
  account = Account.first_or_create!(name: ENV["TOASTER_SEED_ACCOUNT_NAME"].presence || "Toaster")

  admin_email = "admin@toaster.local"
  admin_password = ENV["TOASTER_ADMIN_PASSWORD"]
  if admin_email.present? && admin_password.present?
    user = User.find_or_initialize_by(email: admin_email)
    user.account ||= account
    user.name = ENV["TOASTER_ADMIN_NAME"].presence || admin_email
    user.role = :admin
    if user.new_record?
      user.password = admin_password
      user.password_confirmation = admin_password
    end
    user.save!
  end
end

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
  user.role = :admin
  user.password = dev_password
  user.password_confirmation = dev_password
  user.save!

  load Rails.root.join("db/seeds/development_demo.rb")
  DevelopmentDemoSeeds.run(account: account)
end
