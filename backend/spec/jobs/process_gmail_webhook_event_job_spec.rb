require 'rails_helper'

RSpec.describe ProcessGmailWebhookEventJob, type: :job do
  describe '#perform' do
    it 'marks the webhook event as processed' do
      event = create(:gmail_webhook_event)

      described_class.perform_now(event.id)

      expect(event.reload.processed_at).to be_present
    end

    it 'is idempotent – skips already-processed events' do
      processed_at = 1.hour.ago
      event = create(:gmail_webhook_event, processed_at: processed_at)

      described_class.perform_now(event.id)

      expect(event.reload.processed_at).to be_within(1.second).of(processed_at)
    end

    it 'uses the webhooks queue' do
      expect(described_class.queue_name).to eq('webhooks')
    end
  end
end
