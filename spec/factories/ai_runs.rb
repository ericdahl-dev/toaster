FactoryBot.define do
  factory :ai_run do
    association :account
    run_type { "extraction" }
    llm_model { "gpt-4o-mini" }
    prompt { "Test prompt" }
    response { "Test response" }
  end
end
