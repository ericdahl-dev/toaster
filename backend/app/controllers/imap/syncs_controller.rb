# frozen_string_literal: true

module Imap
  class SyncsController < AccountScopedController
    include MailConnectionSync

    private

    def connections_scope
      @account.imap_connections
    end

    def connection_id_key
      :imap_connection_id
    end
  end
end
