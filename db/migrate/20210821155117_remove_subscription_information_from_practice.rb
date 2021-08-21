class RemoveSubscriptionInformationFromPractice < ActiveRecord::Migration[5.2]
  def change
    remove_column :practices, :number_of_patients, :integer
    remove_column :practices, :plan_id, :integer
    remove_column :practices, :invitation_code, :string
    remove_column :practices, :status, :string
  end
end
