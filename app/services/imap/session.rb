require "net/imap"

module Imap
  module Session
    def self.call(imap_connection:)
      imap = Net::IMAP.new(
        imap_connection.host,
        port: imap_connection.port,
        ssl: imap_connection.ssl?
      )
      imap.login(imap_connection.username, imap_connection.password)
      yield imap
    ensure
      begin
        imap&.disconnect
      rescue
        nil
      end
    end
  end
end
