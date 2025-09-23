# frozen_string_literal: true

class AddCustomReviewUrlToPractices < ActiveRecord::Migration[7.2]
  def change
    add_column :practices, :custom_review_url, :string
  end
end