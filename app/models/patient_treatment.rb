class PatientTreatment < ActiveRecord::Base
   
  # associations
  belongs_to :patient
  belongs_to :doctor
  
  # validations
	validates_presence_of :patient_id, :doctor_id, :name, :price
  validates_length_of :name, :within => 1..100
  validates :notes, :length => { :within => 0..500 }, :allow_blank => true
  validates_numericality_of :price
  
  # callbacks
  after_update :update_balance_from_update
  after_destroy :update_balance_from_destroy
    
  def update_balance_from_update 
    # check to see if the "is_completed" property changed
    if self.changes[:is_completed] != nil
      balance = Balance.new
      balance.patient_id = self.patient_id
      balance.amount = self.price * ((self.changes[:is_completed].last) ? 1 : -1)
      balance.notes = ((self.changes[:is_completed].last) ? _("Charge for") : _("Chargeback for")) + " " + self.name 
      balance.save
    end
  end
  
  def update_balance_from_destroy
    if self.is_completed
      balance = Balance.new
      balance.patient_id = self.patient_id
      balance.amount = self.price * -1
      balance.notes = _("Chargeback for") + " " + self.name 
      balance.save
    end
  end
  
end
