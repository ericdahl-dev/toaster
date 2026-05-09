# frozen_string_literal: true

FactoryBot.define do
  factory :waitlist_entry do
    sequence(:email) { |n| "waitlist#{n}@example.com" }
    full_name { "Jane Operator" }
    company_name { "Venue Co" }
    status { :pending }
  end
end
