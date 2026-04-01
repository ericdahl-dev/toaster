FactoryBot.define do
  factory :gmail_connection do
    association :account
    sequence(:email) { |n| "gmail#{n}@example.com" }
    active { true }

    after(:build) do |connection|
      connection.user ||= build(:user, account: connection.account)
    end
  end
end
