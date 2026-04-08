FactoryBot.define do
  factory :inbox_message do
    association :account
    provider { "agent_mailbox" }
    sequence(:provider_message_id) { |n| "msg-#{n}" }
    sequence(:provider_thread_id) { |n| "thread-#{n}" }
    direction { "inbound" }
    from_name { "Lead Person" }
    sequence(:from_email) { |n| "lead#{n}@example.com" }
    to_emails { ["agent@example.com"] }
    subject { "Test inquiry" }
    body_text { "Hello there" }
    body_html { "<p>Hello there</p>" }
    received_at { Time.current }
    raw_payload { {"messageId" => provider_message_id} }
  end
end
