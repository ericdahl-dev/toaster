class ResetImapPasswordToEncrypted < ActiveRecord::Migration[8.1]
  def up
    # Clear existing plaintext passwords. Credentials must be re-entered after deploy.
    # See: https://github.com/ericdahl-dev/toaster/issues/334
    ImapConnection.in_batches.update_all(password: nil, active: false)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
