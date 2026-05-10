require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Toaster
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Background jobs via GoodJob
    config.active_job.queue_adapter = :good_job
    config.good_job.execution_mode = :async
    config.good_job.enable_cron = true
    config.good_job.cron = {
      sync_all_imap_connections: {
        cron: "*/5 * * * *",
        class: "SyncAllImapConnectionsJob",
        set: { queue: :webhooks },
        description: "Poll all active IMAP inboxes for new messages"
      },
      reconcile_all_drafts: {
        cron: "*/5 * * * *",
        class: "ReconcileAllDraftsJob",
        set: { queue: :mailers },
        description: "Check sent folder for dispatched drafts"
      },
      expire_waitlist_invites: {
        cron: "0 * * * *",
        class: "ExpireWaitlistInvitesJob",
        set: { queue: :default },
        description: "Flip invited WaitlistEntries to expired after Devise reset window"
      }
    }

    config.hosts << "toaster-backend.ger3.ericdahl.dev"
    config.hosts << "toaster.ger3.ericdahl.dev"
    config.hosts << /\A\d+\.toaster\.ger3\.ericdahl\.dev\z/
  end
end
