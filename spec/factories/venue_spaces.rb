# frozen_string_literal: true

FactoryBot.define do
  factory :venue_space do
    association :venue
    name { "Main Room" }
    capacity_seated { nil }
    capacity_reception { 100 }
    min_guests { nil }
    pricing_floor_cents { nil }
  end
end
