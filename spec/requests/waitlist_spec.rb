# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Waitlist", type: :request do
  describe "POST /waitlist" do
    context "with a valid email" do
      it "creates a waitlist entry and renders success" do
        expect {
          post waitlist_path, params: {waitlist_entry: {email: "owner@venue.com"}},
            headers: {"Accept" => "text/html"}
        }.to change(WaitlistEntry, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("You're on the list")
      end

      it "is idempotent — duplicate email does not error" do
        create(:waitlist_entry, email: "owner@venue.com")
        expect {
          post waitlist_path, params: {waitlist_entry: {email: "owner@venue.com"}}
        }.not_to change(WaitlistEntry, :count)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("You're on the list")
      end
    end

    context "with an invalid email" do
      it "re-renders the form with an error" do
        post waitlist_path, params: {waitlist_entry: {email: "notanemail"}}
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("valid email")
      end
    end
  end
end
