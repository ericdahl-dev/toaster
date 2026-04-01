namespace :poc do
  desc "Seed the Toaster agent-mailbox POC demo data"
  task :seed_agent_mailbox_demo, [ :account_name ] => :environment do |_, args|
    result = AgentMailbox::DemoSeed.call(account_name: args[:account_name] || "POC Demo Account")
    puts result.summary
  end
end
