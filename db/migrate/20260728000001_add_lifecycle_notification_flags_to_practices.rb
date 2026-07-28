# frozen_string_literal: true

class AddLifecycleNotificationFlagsToPractices < ActiveRecord::Migration[8.1]
  def change
    add_column :practices, :notified_of_activation_nudge, :boolean, default: false, null: false
    add_column :practices, :notified_of_trial_ending, :boolean, default: false, null: false
    add_column :practices, :notified_of_trial_ended, :boolean, default: false, null: false
    add_column :practices, :notified_of_deletion_warning, :boolean, default: false, null: false
  end
end
