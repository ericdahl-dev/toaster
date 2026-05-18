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

  describe "config/cable.yml" do
    it "uses solid_cable for production (no Redis)" do
      production = YAML.safe_load(
        ERB.new(Rails.root.join("config/cable.yml").read).result,
        aliases: true
      )["production"]

      expect(production["adapter"]).to eq("solid_cable")
    end
  end
end
