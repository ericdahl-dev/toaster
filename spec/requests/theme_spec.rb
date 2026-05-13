# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Color theme (GH-325)", type: :request do
  def first_stylesheet_index(body)
    body.index('rel="stylesheet"')
  end

  describe "theme bootstrap script" do
    it "runs before first stylesheet on landing" do
      get "/"

      theme_idx = response.body.index("toaster-theme")
      css_idx = first_stylesheet_index(response.body)
      expect(theme_idx).to be_present
      expect(css_idx).to be_present
      expect(theme_idx).to be < css_idx
      expect(response.body).to include("prefers-color-scheme")
      expect(response.body).to include('document.documentElement.setAttribute("data-theme"')
    end

    it "runs before first stylesheet on login" do
      get login_path

      theme_idx = response.body.index("toaster-theme")
      css_idx = first_stylesheet_index(response.body)
      expect(theme_idx).to be < css_idx
    end
  end

  describe "theme toggle markup" do
    it "includes toggle in landing nav" do
      get "/"

      expect(response.body).to include('class="theme-toggle"')
      expect(response.body).to include("theme-toggle__svg")
      expect(response.body).not_to include("theme-toggle--floating")
    end

    it "includes floating toggle on login" do
      get login_path

      expect(response.body).to include("theme-toggle--floating")
    end

    it "includes toggle in app topbar when signed in" do
      account = create(:account)
      user = create(:user, account: account)
      sign_in user

      get booking_requests_path

      expect(response.body).to include('class="theme-toggle"')
      expect(response.body).to include('data-controller="theme"')
    end
  end
end
