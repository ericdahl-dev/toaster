# frozen_string_literal: true

require "rails_helper"
require "net/http/post/multipart"

RSpec.describe UnstructuredClient do
  let(:api_key) { "test-unstructured-key" }
  let(:file_path) { Rails.root.join("spec/fixtures/files/event_guide.txt").to_s }

  let(:success_body) do
    JSON.generate([
      { "text" => "Hello world", "metadata" => { "page_number" => 1 } },
      { "text" => "Second paragraph", "metadata" => { "page_number" => 2 } },
      { "text" => nil, "metadata" => { "page_number" => 2 } }
    ])
  end

  let(:http_success) do
    instance_double(Net::HTTPSuccess, is_a?: true, body: success_body).tap do |r|
      allow(r).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    end
  end

  let(:http_error) do
    instance_double(Net::HTTPResponse, code: "422", body: "Unprocessable").tap do |r|
      allow(r).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
    end
  end

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:unstructured, :api_key).and_return(nil)
    stub_const("ENV", ENV.to_h.merge("UNSTRUCTURED_API_KEY" => api_key))
    allow(Net::HTTP).to receive(:start).and_yield(double("http", request: http_success))
  end

  describe ".extract" do
    context "when API key is missing" do
      before do
        stub_const("ENV", ENV.to_h.except("UNSTRUCTURED_API_KEY"))
        allow(Rails.application.credentials).to receive(:dig).with(:unstructured, :api_key).and_return(nil)
      end

      it "raises ConfigurationError" do
        expect { described_class.extract(file_path) }
          .to raise_error(UnstructuredClient::ConfigurationError, /UNSTRUCTURED_API_KEY/)
      end
    end

    context "when API returns success" do
      it "returns extracted text joined by double newlines" do
        result = described_class.extract(file_path)
        expect(result[:text]).to eq("Hello world\n\nSecond paragraph")
      end

      it "returns the max page number as page_count" do
        result = described_class.extract(file_path)
        expect(result[:page_count]).to eq(2)
      end

      it "defaults page_count to 1 when no page_number metadata" do
        no_page_body = JSON.generate([ { "text" => "Hello", "metadata" => {} } ])
        allow(Net::HTTP).to receive(:start).and_yield(
          double("http", request: instance_double(Net::HTTPSuccess,
            is_a?: true, body: no_page_body).tap { |r|
              allow(r).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
            }
          )
        )
        result = described_class.extract(file_path)
        expect(result[:page_count]).to eq(1)
      end
    end

    context "when API returns an error" do
      before do
        allow(Net::HTTP).to receive(:start).and_yield(double("http", request: http_error))
      end

      it "raises ApiError with status code" do
        expect { described_class.extract(file_path) }
          .to raise_error(UnstructuredClient::ApiError, /422/)
      end
    end

    context "when credentials key is set" do
      before do
        stub_const("ENV", ENV.to_h.except("UNSTRUCTURED_API_KEY"))
        allow(Rails.application.credentials).to receive(:dig).with(:unstructured, :api_key).and_return(api_key)
      end

      it "uses the credentials key and succeeds" do
        result = described_class.extract(file_path)
        expect(result[:text]).to be_present
      end
    end
  end
end
