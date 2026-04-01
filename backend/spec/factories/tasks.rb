FactoryBot.define do
  factory :task do
    association :account
    title { "Test Task" }
    status { "open" }

    after(:build) do |task|
      task.booking_request ||= build(:booking_request, account: task.account)
    end
  end
end
