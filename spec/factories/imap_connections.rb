FactoryBot.define do
  factory :imap_connection do
    association :account
    host { "imap.example.com" }
    port { 993 }
    ssl { true }
    sequence(:username) { |n| "user#{n}@example.com" }
    password { "secret" }
    inbox_folder { "INBOX" }
    last_synced_uid { nil }
    active { true }
    smtp_host { nil }
    smtp_port { nil }
  end
end
