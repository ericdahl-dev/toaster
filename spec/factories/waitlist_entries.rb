# frozen_string_literal: true

FactoryBot.define do
  factory :waitlist_entry do
    sequence(:email) { |n| "waitlist#{n}@example.com" }
  end
end
