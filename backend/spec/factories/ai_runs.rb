FactoryBot.define do
  factory :ai_run do
    association :account
    llm_model { "gpt-4" }
    prompt { "Test prompt" }
    response { "Test response" }
  end
end
