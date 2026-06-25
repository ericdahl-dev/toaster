# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Waitlist invite", type: :request do
  let(:admin) { create(:user, role: :admin) }
  let(:venue_manager) { create(:user, role: :venue_manager) }
  let(:entry) { create(:waitlist_entry, status: :pending) }

  describe "GET /admin/waitlist/:id/invite" do
    context "when signed in as admin" do
      it "renders the invite form pre-filled with prospect data" do
        sign_in_as(admin)
        get invite_admin_waitlist_path(entry)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(entry.full_name)
        expect(response.body).to include(entry.company_name)
        expect(response.body).to include(entry.email)
      end
    end

    context "when signed in as venue_manager" do
      it "redirects to root" do
        sign_in_as(venue_manager)
        get invite_admin_waitlist_path(entry)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /admin/waitlist/:id/invite" do
    context "when signed in as admin with valid params" do
      before { sign_in_as(admin) }

      it "creates Account and User in a single transaction" do
        expect {
          post invite_admin_waitlist_path(entry), params: {
            account: { name: entry.company_name },
            user: { name: entry.full_name, email: entry.email }
          }
        }.to change(Account, :count).by(1).and change(User, :count).by(1)
      end

      it "creates the user as a venue_manager" do
        post invite_admin_waitlist_path(entry), params: {
          account: { name: entry.company_name },
          user: { name: entry.full_name, email: entry.email }
        }
        expect(User.find_by(email: entry.email).role).to eq("venue_manager")
      end

      it "marks the WaitlistEntry as invited" do
        post invite_admin_waitlist_path(entry), params: {
          account: { name: entry.company_name },
          user: { name: entry.full_name, email: entry.email }
        }
        expect(entry.reload).to be_invited
        expect(entry.reload.invited_at).to be_present
      end

      it "enqueues an invite email" do
        expect {
          post invite_admin_waitlist_path(entry), params: {
            account: { name: entry.company_name },
            user: { name: entry.full_name, email: entry.email }
          }
        }.to have_enqueued_mail(WaitlistMailer, :invite)
      end

      it "redirects to waitlist index with notice" do
        post invite_admin_waitlist_path(entry), params: {
          account: { name: entry.company_name },
          user: { name: entry.full_name, email: entry.email }
        }
        expect(response).to redirect_to(admin_waitlist_index_path)
        expect(flash[:notice]).to be_present
      end
    end

    context "with invalid params" do
      it "re-renders form without creating records" do
        sign_in_as(admin)
        expect {
          post invite_admin_waitlist_path(entry), params: {
            account: { name: "" },
            user: { name: "", email: "" }
          }
        }.not_to change(Account, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
