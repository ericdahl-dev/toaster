FactoryBot.define do
  factory :user do
    association :account
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
  end
end
