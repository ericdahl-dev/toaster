# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Waitlist", type: :request do
  let(:valid_params) do
    {waitlist_entry: {email: "owner@venue.com", full_name: "Jane Operator", company_name: "Venue Co"}}
  end

  describe "POST /waitlist" do
    context "with valid params" do
      it "creates a waitlist entry and renders success" do
        expect {
          post waitlist_path, params: valid_params, headers: {"Accept" => "text/html"}
        }.to change(WaitlistEntry, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("You're on the list")
      end

      it "enqueues a confirmation email" do
        expect {
          post waitlist_path, params: valid_params
        }.to have_enqueued_mail(WaitlistMailer, :confirmation)
      end

      it "is idempotent — duplicate email does not error" do
        create(:waitlist_entry, email: "owner@venue.com")
        expect {
          post waitlist_path, params: valid_params
        }.not_to change(WaitlistEntry, :count)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("You're on the list")
      end

      it "does not enqueue a confirmation email for a duplicate signup" do
        create(:waitlist_entry, email: "owner@venue.com")
        expect {
          post waitlist_path, params: valid_params
        }.not_to have_enqueued_mail(WaitlistMailer, :confirmation)
      end
    end

    context "with an invalid email" do
      it "re-renders the form with an error" do
        post waitlist_path, params: {waitlist_entry: {email: "notanemail", full_name: "Jane", company_name: "Venue Co"}}
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("valid email")
      end
    end
  end
end
