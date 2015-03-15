class Appointment < ActiveRecord::Base
	# permitted attributes
  attr_accessible :datebook_id, :doctor_id, :patient_id, :starts_at, :ends_at, :notes

  # associations
  belongs_to :datebook
  belongs_to :doctor
  belongs_to :patient

  scope :find_between, lambda { |starts_at, ends_at|
  	includes(:doctor, :patient)
    .where("appointments.starts_at > ? AND appointments.ends_at < ?", Time.at(starts_at.to_i), Time.at(ends_at.to_i))
    .order("appointments.starts_at")
  }

  scope :find_from_doctor_and_between, lambda { |doctor_id, starts_at, ends_at|
    where("appointments.doctor_id = ?", doctor_id)
    .find_between starts_at, ends_at
  }

  # validations
  validates_presence_of :datebook_id, :doctor_id, :patient_id
  validates_numericality_of :datebook_id, :doctor_id, :patient_id
  validate :ends_at_should_be_later_than_starts_at, :practice_is_mine
  validates :notes, :length => { :within => 0..255 }, :allow_blank => true

  # callbacks
  before_create :set_ends_at

  # Overwrite de JSON response to comply with what the event calendar wants
  # this needs to be overwritten in the "web" version and not the whole app
  def as_json(options = {})
      {
      	:id => id,
        :start => starts_at.to_formatted_s(:rfc822),
        :end => ends_at.to_formatted_s(:rfc822),
        :title => notes,
        :doctor_id => doctor_id,
        :datebook_id => datebook_id,
        :patient_id => patient_id,
        :color => doctor.color,
        :doctor_name => doctor.fullname,
        :firstname => patient.firstname,
        :lastname => patient.lastname
      }
	end

  # find all the appointments of a give patient and arrange them
  # in past and future hashes
  def self.find_all_past_and_future_for_patient(patient_id)
    query = Appointment.where("patient_id = ?", patient_id).includes(:doctor).order("starts_at desc")

    appointments = {
      :future => [],
      :past => []
    }

    today = Date.today.beginning_of_day

    query.each do |appointment|
      if appointment.starts_at > today
        appointments[:future] << appointment
      else
        appointments[:past] << appointment
      end

    end

    return appointments
  end

  def ciphered_url
    ciphered_url_encoded_id = Cipher.encode(self.id.to_s)

    return "http://my.odonto.me/datebooks/#{self.datebook_id.to_s}/appointments/#{ciphered_url_encoded_id}"
  end

  private

  def ends_at_should_be_later_than_starts_at
  	if !self.starts_at.nil? && !self.ends_at.nil?
	  	if self.starts_at >= self.ends_at
	  		self.errors[:base] << I18n.t("errors.messages.invalid_date_range")
	  	end
	  end
  end

  def practice_is_mine
    begin
      is_mine = Datebook.mine.find self.datebook_id

      rescue ActiveRecord::RecordNotFound
        self.errors[:base] << I18n.t("errors.messages.invalid_practice_id")
    end
  end

  def set_ends_at
  	if self.ends_at.nil?
    	self.ends_at = self.starts_at + 60.minutes
    end
  end

end
