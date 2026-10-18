class HashUserRememberTokens < ActiveRecord::Migration[8.1]
  # Remember tokens are now stored as SHA-256 digests. Plain tokens can't be
  # converted (the browser holds the raw value we'd need to match), so they
  # are dropped: people who ticked "remember me" sign in once more the next
  # time their browser session runs out.
  def change
    remove_index :users, :remember_token, name: "index_users_on_remember_token"
    remove_column :users, :remember_token, :string
    add_column :users, :remember_token_digest, :string
    add_index :users, :remember_token_digest
  end
end
