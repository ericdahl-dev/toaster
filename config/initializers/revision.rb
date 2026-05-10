# frozen_string_literal: true

revision_file = Rails.root.join("REVISION")
APP_REVISION = revision_file.exist? ? revision_file.read.strip : "dev"
