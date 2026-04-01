namespace :poc do
  desc "Seed the Toaster agent-mailbox POC demo data"
  task :seed_agent_mailbox_demo, [ :account_name ] => :environment do |_, args|
    unless Rails.env.development? || Rails.env.test?
      abort "poc:seed_agent_mailbox_demo can only be run in development or test environments."
    end

    result = AgentMailbox::DemoSeed.call(account_name: args[:account_name] || "POC Demo Account")
    puts result.summary
  end
end
