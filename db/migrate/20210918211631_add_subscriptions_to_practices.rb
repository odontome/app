class AddSubscriptionsToPractices < ActiveRecord::Migration[5.2]
  def change
    create_table :subscriptions do |t|
      t.belongs_to :practice, foreign_key: true, null: false, index: true
      t.text :status, null: false
      t.boolean :cancel_at_period_end, null: false, default: false
      t.datetime :current_period_start, null: false
      t.datetime :current_period_end, null: false
      t.timestamps null: false
    end

    add_column :practices, :stripe_customer_id, :text

    reversible do |dir|
      dir.up do
        create_trial_subscription
      end
      dir.down do
        # nothing, rails will drop the table
      end
    end
  end

  def create_trial_subscription
    say_with_time "Adding trial to each practice" do
      Practice.all.find_each do |practice|
        say "Creating subscription for practice: #{practice.id}"
        subscription = Subscription.new(
          practice_id: practice.id,
          status: 'active', 
          cancel_at_period_end: true, 
          current_period_start: Time.now,
          current_period_end: 30.days.from_now)
        subscription.save!
      end
    end

    fail "Mismatch of subscriptions and practices" unless Practice.all.count == Subscription.all.count
  end
end
