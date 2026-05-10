# frozen_string_literal: true

require "rails_helper"

RSpec.describe OpsController do
  describe "auth concern delegation" do
    it "does not define require_ops_auth! as its own method (delegates to Ops::RequireToken)" do
      own_privates = described_class.private_instance_methods(false)
      expect(own_privates).not_to include(:require_ops_auth!)
    end

    it "does not define require_ops_admin! as its own method (delegates to Ops::RequireAdmin)" do
      own_privates = described_class.private_instance_methods(false)
      expect(own_privates).not_to include(:require_ops_admin!)
    end
  end
end
