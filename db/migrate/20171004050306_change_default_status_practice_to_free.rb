# frozen_string_literal: true

class ChangeDefaultStatusPracticeToFree < ActiveRecord::Migration[5.1]
  def up
    change_column_default :practices, :status, :free
  end
end
