class PatientTreatment < ActiveRecord::Base
   
  # associations
  belongs_to :patient
  belongs_to :doctor
  
  # validations
  validates_presence_of :patient_id, :doctor_id, :name, :tooth_number, :price
  validates_length_of :name, :within => 1..100
  validates_numericality_of :price
  validates_numericality_of :tooth_number, :only_integer => true
  
  # callbacks
  after_update :update_balance_from_update
  after_destroy :update_balance_from_destroy
  
  # constants
  TEETH = [ [11, 11],
            [12, 12],
            [13, 13],
            [14, 14],
            [15, 15],
            [16, 16],
            [17, 17],
            [18, 18],
            [21, 21],
            [22, 22],
            [23, 23],
            [24, 24],
            [25, 25],
            [26, 26],
            [27, 27],
            [28, 28],
            [_('N/A'), 0] ]
  
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
