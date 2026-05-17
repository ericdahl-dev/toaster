# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Cuprite driver", type: :system, js: true do
  it "runs javascript-enabled system tests" do
    visit root_path

    page.execute_script("document.body.dataset.cupriteCheck = 'ok'")

    expect(page).to have_css("body[data-cuprite-check='ok']")
  end
end
