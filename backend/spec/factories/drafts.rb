FactoryBot.define do
  factory :draft do
    association :account
    body { "Draft body text" }
    status { "pending_review" }
    original_body { nil }
    imap_draft_uid { nil }

    after(:build) do |draft|
      draft.booking_request ||= build(:booking_request, account: draft.account)
    end
  end
end
