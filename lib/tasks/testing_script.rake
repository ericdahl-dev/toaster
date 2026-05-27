namespace :testing do
  desc "Send a customer-side test email via Resend and verify IMAP receipt in Toaster"
  task :email_script, [ :account_id, :connection_id ] => :environment do |_, args|
    result = Toaster::LocalEmailTester.call(
      from_email: ENV.fetch("TOASTER_TEST_CUSTOMER_EMAIL"),
      from_name: ENV.fetch("TOASTER_TEST_CUSTOMER_NAME", "Test Customer"),
      subject: ENV["TOASTER_TEST_SUBJECT"],
      body: ENV["TOASTER_TEST_BODY"],
      account_id: args[:account_id],
      connection_id: args[:connection_id],
      timeout_seconds: ENV.fetch("TOASTER_TEST_TIMEOUT", 60),
      poll_interval_seconds: ENV.fetch("TOASTER_TEST_POLL_INTERVAL", 5)
    )

    puts "Sent and received test email."
    puts "IMAP username: #{result.connection.username}"
    puts "Inbox folder: #{result.connection.inbox_folder}"
    puts "From: #{result.from_email}"
    puts "Subject: #{result.subject}"
    puts "Matched IMAP UIDs: #{result.matched_uids.join(", ")}"
  rescue KeyError
    abort "TOASTER_TEST_CUSTOMER_EMAIL must be set."
  rescue Toaster::LocalEmailTester::Error => e
    abort e.message
  end
end
