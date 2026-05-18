# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Action Cable configuration" do
  let(:cable_yml) { Rails.root.join("config/cable.yml") }

  it "uses solid_cable in production on the primary database" do
    production = YAML.safe_load(ERB.new(cable_yml.read).result, aliases: true)["production"]

    expect(production["adapter"]).to eq("solid_cable")
    expect(production).not_to have_key("connects_to")
    expect(production).not_to have_key("url")
  end

  it "does not require redis in the Gemfile" do
    gemfile = Rails.root.join("Gemfile").read

    expect(gemfile).to include("solid_cable")
    expect(gemfile).not_to match(/^\s*gem ["']redis["']/m)
  end
end
