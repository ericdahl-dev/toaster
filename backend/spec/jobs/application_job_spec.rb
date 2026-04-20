require "rails_helper"

RSpec.describe ApplicationJob, type: :job do
  let(:log_lines) { [] }

  before do
    allow(Rails.logger).to receive(:info) { |line| log_lines << line }
    allow(Rails.logger).to receive(:warn) { |line| log_lines << line }
    allow(Rails.logger).to receive(:error) { |line| log_lines << line }
  end

  describe "shared lifecycle logging" do
    let(:success_job_class) do
      Class.new(ApplicationJob) do
        def perform(_id)
          true
        end
      end
    end

    let(:failure_job_class) do
      Class.new(ApplicationJob) do
        def perform
          raise ArgumentError, "boom"
        end
      end
    end

    let(:discard_job_class) do
      Class.new(ApplicationJob) do
        discard_on ActiveRecord::RecordNotFound

        def perform
          raise ActiveRecord::RecordNotFound, "missing"
        end
      end
    end

    it "logs start and success metadata" do
      success_job_class.perform_now(123)

      output = log_lines.join("\n")
      expect(output).to include("job_start")
      expect(output).to include("job_success")
      expect(output).to include("job_class")
      expect(output).to include("job_id")
      expect(output).to include("queue")
      expect(output).to include("duration_ms")
    end

    it "logs failure metadata and re-raises" do
      expect { failure_job_class.perform_now }.to raise_error(ArgumentError, "boom")

      output = log_lines.join("\n")
      expect(output).to include("job_failure")
      expect(output).to include("ArgumentError")
      expect(output).to include("boom")
      expect(output).to include("job_class")
      expect(output).to include("job_id")
    end

    it "logs discard metadata" do
      expect { discard_job_class.perform_now }.not_to raise_error

      output = log_lines.join("\n")
      expect(output).to include("job_discard")
      expect(output).to include("ActiveRecord::RecordNotFound")
      expect(output).to include("job_class")
      expect(output).to include("job_id")
    end
  end
end
