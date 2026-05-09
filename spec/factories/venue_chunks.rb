# frozen_string_literal: true

FactoryBot.define do
  factory :venue_chunk do
    association :venue_document
    content { "The Rooftop can accommodate up to 150 guests reception-style." }
    embedding { Array.new(3072, 0.0) }
  end
end
