# frozen_string_literal: true

FactoryBot.define do
  factory :venue_document do
    association :venue
    source_filename { "event_guide.pdf" }
    status { :pending }
  end
end
