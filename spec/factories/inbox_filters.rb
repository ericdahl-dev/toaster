FactoryBot.define do
  factory :inbox_filter do
    association :imap_connection
    association :venue
    keyword { "wedding" }
    position { 0 }
  end
end
