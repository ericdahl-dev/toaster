FactoryBot.define do
  factory :booking_request do
    association :account
    status { "pending" }
    event_date { Date.today + 30 }
    extraction_snapshot { {} }
    missing_fields { [] }
    review_reasons { [] }
    feature_preferences { [] }

    after(:build) do |br|
      br.contact ||= build(:contact, account: br.account)
      br.conversation_thread ||= build(:conversation_thread, account: br.account, contact: br.contact)
    end
  end
end
