require "rails_helper"

RSpec.describe GmailWatchService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:connection) do
    create(:gmail_connection,
      account: account,
      user: user,
      access_token: "ya29.access",
      refresh_token: "1//refresh",
      token_expires_at: 1.hour.from_now
    )
  end
  let(:oauth_service) { instance_double(GmailOauthService) }
  let(:service) { described_class.new(connection, oauth_service: oauth_service) }

  let(:watch_response_data) do
    {
      "historyId" => "12345",
      "expiration" => ((Time.current + 7.days).to_i * 1000).to_s
    }
  end

  describe "#setup" do
    it "sets up a Gmail watch and updates the connection" do
      allow(service).to receive(:call_watch_api).and_return(watch_response_data)

      result = service.setup(topic_name: "projects/test/topics/gmail")

      expect(result.watch_history_id).to eq("12345")
      expect(result.watch_expiration).to be_within(5.seconds).of(Time.current + 7.days)
    end

    it "raises Error when watch setup fails" do
      allow(service).to receive(:call_watch_api).and_raise(GmailWatchService::Error, "Pub/Sub topic does not exist")

      expect {
        service.setup(topic_name: "projects/test/topics/gmail")
      }.to raise_error(GmailWatchService::Error, "Pub/Sub topic does not exist")
    end

    context "when access token is expired" do
      before { connection.update!(token_expires_at: 1.hour.ago) }

      it "refreshes the token before setting up the watch" do
        allow(oauth_service).to receive(:refresh_access_token).with("1//refresh").and_return({
          "access_token" => "ya29.new",
          "expires_in" => 3600
        })
        allow(service).to receive(:call_watch_api).and_return(watch_response_data)

        service.setup(topic_name: "projects/test/topics/gmail")

        expect(oauth_service).to have_received(:refresh_access_token).with("1//refresh")
        expect(connection.reload.access_token).to eq("ya29.new")
      end
    end

    context "when token is still valid" do
      it "does not refresh the token" do
        allow(oauth_service).to receive(:refresh_access_token)
        allow(service).to receive(:call_watch_api).and_return(watch_response_data)

        service.setup(topic_name: "projects/test/topics/gmail")

        expect(oauth_service).not_to have_received(:refresh_access_token)
      end
    end
  end

  describe "#renew" do
    it "calls setup to renew the watch" do
      allow(service).to receive(:call_watch_api).and_return(watch_response_data)

      result = service.renew(topic_name: "projects/test/topics/gmail")

      expect(result.watch_expiration).to be_present
    end

    it "raises Error when renewal fails" do
      allow(service).to receive(:call_watch_api).and_raise(GmailWatchService::Error, "Watch renewal failed")

      expect {
        service.renew(topic_name: "projects/test/topics/gmail")
      }.to raise_error(GmailWatchService::Error, "Watch renewal failed")
    end
  end

  describe "#stop" do
    before do
      connection.update!(
        watch_resource_id: "res_123",
        watch_history_id: "12345",
        watch_expiration: 2.days.from_now
      )
    end

    it "clears watch fields on the connection" do
      allow(service).to receive(:call_stop_api)

      service.stop

      connection.reload
      expect(connection.watch_resource_id).to be_nil
      expect(connection.watch_history_id).to be_nil
      expect(connection.watch_expiration).to be_nil
    end
  end
end
