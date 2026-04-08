FactoryBot.define do
  factory :conversation_thread do
    association :account
    sequence(:provider_thread_id) { |n| "thread_#{n}" }
    subject { "Test Subject" }

    after(:build) do |thread|
      thread.contact ||= build(:contact, account: thread.account)
    end
  end
end
