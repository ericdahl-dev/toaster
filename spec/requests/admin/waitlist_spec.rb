# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Waitlist", type: :request do
  let(:admin) { create(:user, role: :admin) }
  let(:venue_manager) { create(:user, role: :venue_manager) }

  describe "GET /admin/waitlist" do
    context "when unauthenticated" do
      it "redirects to login" do
        get admin_waitlist_index_path
        expect(response).to redirect_to("/login")
      end
    end

    context "when signed in as venue_manager" do
      it "redirects to root with a flash" do
        sign_in_as(venue_manager)
        get admin_waitlist_index_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when signed in as admin" do
      before { sign_in_as(admin) }

      it "renders the waitlist index" do
        get admin_waitlist_index_path
        expect(response).to have_http_status(:ok)
      end

      it "lists prospects with name, company, email, status" do
        create(:waitlist_entry, full_name: "Jane Operator", company_name: "Venue Co", status: :pending)
        create(:waitlist_entry, full_name: "Bob Manager", company_name: "Hall Inc", status: :invited)

        get admin_waitlist_index_path

        expect(response.body).to include("Jane Operator")
        expect(response.body).to include("Venue Co")
        expect(response.body).to include("Bob Manager")
        expect(response.body).to include("pending")
        expect(response.body).to include("invited")
      end

      it "shows an Invite link for pending entries" do
        create(:waitlist_entry, status: :pending)
        get admin_waitlist_index_path
        expect(response.body).to include("Invite")
      end

      it "does not show an Invite link for converted entries" do
        entry = create(:waitlist_entry, status: :converted)
        get admin_waitlist_index_path
        expect(response.body).not_to include(invite_admin_waitlist_path(entry))
      end
    end
  end
end
