namespace :testing do
  desc "Send a customer-side test email via Resend and verify IMAP receipt in Toaster"
  task :email_script, [ :account_id, :connection_id ] => :environment do |_, args|
    wait_for_response = ActiveModel::Type::Boolean.new.cast(ENV["TOASTER_TEST_WAIT_FOR_TOASTER_RESPONSE"])

    result = Toaster::LocalEmailTester.call(
      from_email: ENV.fetch("TOASTER_TEST_CUSTOMER_EMAIL"),
      from_name: ENV.fetch("TOASTER_TEST_CUSTOMER_NAME", "Test Customer"),
      subject: ENV["TOASTER_TEST_SUBJECT"],
      body: ENV["TOASTER_TEST_BODY"],
      account_id: args[:account_id],
      connection_id: args[:connection_id],
      timeout_seconds: ENV.fetch("TOASTER_TEST_TIMEOUT", 60),
      poll_interval_seconds: ENV.fetch("TOASTER_TEST_POLL_INTERVAL", 5),
      wait_for_response: wait_for_response,
      customer_imap_host: ENV["TOASTER_TEST_CUSTOMER_IMAP_HOST"],
      customer_imap_port: ENV.fetch("TOASTER_TEST_CUSTOMER_IMAP_PORT", 993),
      customer_imap_ssl: ActiveModel::Type::Boolean.new.cast(ENV.fetch("TOASTER_TEST_CUSTOMER_IMAP_SSL", true)),
      customer_imap_username: ENV["TOASTER_TEST_CUSTOMER_IMAP_USERNAME"],
      customer_imap_password: ENV["TOASTER_TEST_CUSTOMER_IMAP_PASSWORD"],
      customer_imap_inbox_folder: ENV.fetch("TOASTER_TEST_CUSTOMER_IMAP_INBOX", "INBOX")
    )

    puts "Sent and received test email."
    puts "IMAP username: #{result.connection.username}"
    puts "Inbox folder: #{result.connection.inbox_folder}"
    puts "From: #{result.from_email}"
    puts "Subject: #{result.subject}"
    puts "Matched IMAP UIDs: #{result.matched_uids.join(", ")}"
    if result.response_uids.any?
      puts "Toaster response UIDs in customer inbox: #{result.response_uids.join(", ")}"
    else
      puts "Toaster response check skipped (set TOASTER_TEST_WAIT_FOR_TOASTER_RESPONSE=true and provide customer IMAP credentials to enable)."
    end
  rescue KeyError => e
    abort "#{e.key} must be set."
  rescue Toaster::LocalEmailTester::Error => e
    abort e.message
  end
end
