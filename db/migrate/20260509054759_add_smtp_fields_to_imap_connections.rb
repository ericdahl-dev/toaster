class AddSmtpFieldsToImapConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :imap_connections, :smtp_host, :string
    add_column :imap_connections, :smtp_port, :integer
  end
end
