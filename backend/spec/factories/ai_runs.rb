FactoryBot.define do
  factory :ai_run do
    association :account
    model_name { "gpt-4" }
    prompt { "Test prompt" }
    response { "Test response" }
  end
end
