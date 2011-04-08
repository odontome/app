class PatientTreatment < ActiveRecord::Base
   
  # associations
  has_many :notes, :as => :noteable, :dependent => :destroy
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
  TEETH = [ [11, 11],[12, 12],[13, 13],[14, 14],[15, 15],[16, 16],[17, 17],[18, 18],
            [21, 21],[22, 22],[23, 23],[24, 24],[25, 25],[26, 26],[27, 27],[28, 28],
            [31, 31],[32, 32],[33, 33],[34, 34],[35, 35],[36, 36],[37, 37],[38, 38],
            [31, 31],[32, 32],[33, 33],[34, 34],[35, 35],[36, 36],[37, 37],[38, 38],
            [41, 41],[42, 42],[43, 43],[44, 44],[45, 45],[46, 46],[47, 47],[48, 48],
            [51, 51],[52, 52],[53, 53],[54, 54],[55, 55],[71, 71],[72, 72],[73, 73],[74, 74],[75, 75],
            [61, 61],[62, 62],[63, 63],[64, 64],[65, 65],[81, 81],[82, 82],[83, 83],[84, 84],[85, 85],
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
