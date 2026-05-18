# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Deployment scripts" do
  describe "bin/docker-entrypoint" do
    let(:entrypoint) { File.read(Rails.root.join("bin/docker-entrypoint")) }

    it "runs db:prepare before starting the web server" do
      expect(entrypoint).to include("db:prepare")
    end

    it "does not reference solid_queue (replaced by GoodJob)" do
      expect(entrypoint).not_to include("solid_queue")
    end

    it "is executable" do
      expect(File.executable?(Rails.root.join("bin/docker-entrypoint"))).to be true
    end
  end

  describe "bin/release" do
    let(:release_script) { Rails.root.join("bin/release") }

    it "exists" do
      expect(release_script).to exist
    end

    it "is executable" do
      expect(File.executable?(release_script)).to be true
    end

    it "runs db:migrate" do
      expect(File.read(release_script)).to include("db:migrate")
    end
  end

  describe "docker-compose.yml" do
    let(:compose) { File.read(Rails.root.join("docker-compose.yml")) }

    it "defines a Redis service for Action Cable" do
      expect(compose).to include("redis:7-alpine")
    end

    it "sets REDIS_URL on web and worker" do
      expect(compose).to include("REDIS_URL: redis://redis:6379/1")
    end
  end
end
