FactoryBot.define do
  factory :agentmail_connection do
    association :account
    sequence(:inbox_id) { |n| "inbox#{n}@agentmail.to" }
    api_key { "test-api-key" }
    active { true }
    last_synced_at { nil }
  end
end
