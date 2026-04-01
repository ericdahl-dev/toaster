FactoryBot.define do
  factory :message do
    association :account
    direction { "inbound" }
    sent_at { Time.current }

    after(:build) do |message|
      message.conversation_thread ||= build(:conversation_thread, account: message.account)
    end
  end
end
