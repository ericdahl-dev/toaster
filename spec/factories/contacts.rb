FactoryBot.define do
  factory :contact do
    association :account
    name { "Test Contact" }
    sequence(:email) { |n| "contact#{n}@example.com" }
  end
end
