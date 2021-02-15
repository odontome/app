# frozen_string_literal: true

class RemovePlansTable < ActiveRecord::Migration[5.0]
  def up
    drop_table :plans
  end

  def down
    create_table :plans, &:timestamps
  end
end
