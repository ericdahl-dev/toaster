FactoryBot.define do
  factory :venue do
    association :account
    name { "Test Venue" }
    address { "123 Main St" }
    capacity { 100 }
  end
end
