class AddSessionTokenToUsers < ActiveRecord::Migration[8.1]
  # No backfill on purpose: a nil token means "signed in before session tokens
  # existed" and is accepted until the user's next sign-in or password change,
  # so nobody is signed out by the deploy.
  def change
    add_column :users, :session_token, :string
  end
end
