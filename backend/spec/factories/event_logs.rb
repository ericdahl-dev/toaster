FactoryBot.define do
  factory :event_log do
    association :account
    event_type { "test.event" }
    payload { {message: "test"} }
  end
end
