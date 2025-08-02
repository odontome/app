# frozen_string_literal: true

class Treatment < ApplicationRecord
  # associations
  belongs_to :practice

  scope :with_practice, lambda { |practice_id|
    where('treatments.practice_id = ? ', practice_id)
      .order('name')
  }

  scope :valid, lambda {
    where('price IS NOT NULL')
      .where('price != 0')
  }

  scope :search, lambda { |q|
    # Escape special characters to prevent SQL injection and PostgreSQL LIKE pattern errors
    escaped_q = ActiveRecord::Base.sanitize_sql_like(q)
    select('id,name,price')
      .where("lower(name) LIKE ?", "%#{escaped_q.downcase}%")
      .limit(25)
      .order('name')
  }

  # validations
  validates_presence_of :practice_id, :name, :price
  validates_length_of :name, within: 1..100
  validates_numericality_of :price

  # callbacks

  def missing_info?
    price.nil? || price <= 0
  end
end
