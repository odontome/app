class AddUnsubscribeFromDigestToUser < ActiveRecord::Migration
  def change
    add_column :users, :subscribed_to_digest, :boolean, :default => true
  end
end
