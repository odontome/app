class AddUnsubscribeFromDigestToUser < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :subscribed_to_digest, :boolean, :default => true
  end
end
