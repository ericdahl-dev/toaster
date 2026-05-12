# frozen_string_literal: true

if Rails.env.production?
  %w[OPENAI_API_KEY UNSTRUCTURED_API_KEY].each do |key|
    raise "Required environment variable #{key} is not set" if ENV[key].blank?
  end
end
