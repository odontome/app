class Balance < ActiveRecord::Base
  # permitted attributes
  attr_accessible :patient_id, :amount, :notes

  # associations
  belongs_to :patient

  # named scopes
  scope :find_between, lambda { |starts_at, ends_at, practice_id|
  	select("patients.uid, patients.id as patient_id, patients.firstname, patients.lastname, balances.id, balances.created_at, balances.amount, balances.notes")
  	.joins('left outer join patients on balances.patient_id = patients.id')
    .where("balances.created_at >= ? AND balances.created_at <= ? AND patients.practice_id = ?", Time.at(starts_at.to_i), Time.at(ends_at.to_i), practice_id)
    .order("balances.created_at")
  }

  # validations
  validates_presence_of :amount, :patient_id
  validates_numericality_of :amount
  validates :notes, :length => 0..160, :presence => false

end
