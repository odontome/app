# frozen_string_literal: true

class AddSixMonthReminderFlagToPatients < ActiveRecord::Migration[7.0]
  def change
    add_column :patients, :notified_of_six_month_reminder, :boolean, default: false, null: false
  end
end
