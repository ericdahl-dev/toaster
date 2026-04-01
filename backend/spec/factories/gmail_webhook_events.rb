FactoryBot.define do
  factory :gmail_webhook_event do
    association :account
    gmail_history_id { "12345" }
    raw_payload { { data: "test" } }
  end
end
