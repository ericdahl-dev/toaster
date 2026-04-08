# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Solid Queue vs database pool" do
  # Mirrors SolidQueue::Configuration#estimated_number_of_threads (solid_queue ~1.4):
  # max(worker threads in queue.yml) + 2
  def solid_queue_estimated_threads
    rendered = ERB.new(Rails.root.join("config/queue.yml").read).result
    cfg = YAML.safe_load(rendered, aliases: true)
    workers = cfg.dig("production", "workers") || []
    max_threads = workers.map { |w| w.fetch("threads", 3).to_i }.max
    max_threads + 2
  end

  def production_pool_after_erb(**env)
    saved = {}
    begin
      env.each do |key, value|
        k = key.to_s
        saved[k] = ENV.key?(k) ? ENV[k] : :__unset__
        if value.nil?
          ENV.delete(k)
        else
          ENV[k] = value
        end
      end
      rendered = ERB.new(Rails.root.join("config/database.yml").read).result
      YAML.safe_load(rendered, aliases: true).dig("production", "pool")
    ensure
      saved.each do |k, prev|
        if prev == :__unset__
          ENV.delete(k)
        else
          ENV[k] = prev
        end
      end
    end
  end

  it "production pool is at least Solid Queue's estimated thread count" do
    required = solid_queue_estimated_threads

    pool = production_pool_after_erb(
      "DB_POOL" => nil,
      "RAILS_MAX_THREADS" => ENV.fetch("RAILS_MAX_THREADS", "5")
    )

    expect(pool).to be >= required
  end
end
