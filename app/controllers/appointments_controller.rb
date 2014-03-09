class AppointmentsController < ApplicationController
  # filters
  before_filter :require_user, :except => :show
  
  # provides
  respond_to :html, :json
  
  #layout
  layout false
  
  def index
    datebook = Datebook.mine.find params[:datebook_id]

    if (params[:doctor_id])
      @appointments = datebook.appointments.find_from_doctor_and_between(params[:doctor_id], params[:start], params[:end])
    else
      @appointments = datebook.appointments.find_between(params[:start], params[:end])
    end
     
     respond_with(@appointments, :methods => ["doctor","patient"])
  end
  
  def new
    @datebook = Datebook.mine.find params[:datebook_id]
    @appointment = Appointment.new
    @appointment.starts_at = params[:starts_at]
    @doctors = Doctor.mine.valid
  end
  
  def create
    @appointment = Appointment.new(params[:appointment])
    @appointment.starts_at = Time.at(params[:appointment][:starts_at].to_i)
    @appointment.datebook_id = params[:datebook_id]

    # if "as_values_patient_id" is not empty use that, otherwise use "patient_id"
    @appointment.patient_id = Patient.find_or_create_from((params[:as_values_patient_id] != "") ? (params[:as_values_patient_id]) : (params[:appointment][:patient_id]))
    
    respond_to do |format|
      if @appointment.save
          format.js  { } #create.js.erb
      else
          format.js  {
            render_ujs_error(@appointment, I18n.t(:appointment_created_error_message))
          }
      end
    end

  end

  def show
    cipher = Gibberish::AES.new(Rails.configuration.secret_token)
    
    appointment_id_deciphered = cipher.dec(Base64.strict_decode64(params[:id]))

    datebook = Datebook.find params[:datebook_id]
    appointment = Appointment.where(:id => appointment_id_deciphered, :datebook_id => datebook.id).first

    # create this here, otherwise it will be a local variable inside the 
    # I18n block
    pass = nil

    # temporaly change the locale
    I18n.with_locale(datebook.practice.locale) do
      pass = Passbook::PKPass.new '{
                  "formatVersion" : 1,
                  "passTypeIdentifier" : "pass.me.odonto.patient.reminder",
                  "serialNumber" : "'+appointment.id.to_s+'",
                  "teamIdentifier" : "R64MTWS872",
                  "organizationName" : "Odonto.me",
                  "description" : "Patient appointment",
                  "foregroundColor" : "#1ca5ef",
                  "backgroundColor" : "#ffffff",
                  "relevantDate" : "' + I18n.l(appointment.starts_at, :format => :w3c) + '",
                  "expirationDate" : "' + I18n.l(appointment.ends_at, :format => :w3c) + '",
                  "barcode" : {
                      "message" : "https://my.odonto.me/patients/' + appointment.patient_id.to_s + '",
                      "format" : "PKBarcodeFormatQR",
                      "messageEncoding" : "UTF8"
                  },
                  "eventTicket": {
                    "headerFields": [
                      {
                        "key" : "date",
                        "label" : "' + I18n.l(appointment.starts_at.to_date, :format => :day_and_date) + '",
                        "value" : "' + I18n.l(appointment.starts_at.to_time.in_time_zone(datebook.practice.timezone), :format => :just_the_time) + '"
                      }
                    ],
                     "primaryFields" : [
                          {
                         "key" : "location",
                         "label" : "Practice",
                         "value" :  "' + datebook.practice.name + '"
                         }
                     ],
                     "secondaryFields" : [
                        {
                         "key" : "doctor",
                         "label" : "Doctor",
                         "value" : "' + appointment.doctor.fullname + '"
                         }
                     ],
                     "backFields" : [
                        {
                            "key" : "website",
                            "label" : "' + I18n.t(:more_information) + '",
                            "value" : "http://www.odonto.me"
                        }
                      ]
                  }
              }'
    end

    pass.addFiles ['passbook/logo.png', 'passbook/logo@2x.png', 'passbook/icon.png', 'passbook/icon@2x.png']

    pkpass = pass.stream
    send_data pkpass.string, :type => 'application/vnd.apple.pkpass', :disposition => 'attachment', :filename => "pass.pkpass"

  end
  
  def edit
    @datebook = Datebook.mine.find params[:datebook_id]
    @appointment = Appointment.where(:id => params[:id], :datebook_id => @datebook.id).first
    @patient = Patient.mine.find(params[:patient_id])
    @doctors = Doctor.mine.valid
  end
  
  def update
    datebook = Datebook.mine.find params[:datebook_id]
    @appointment = Appointment.where(:id => params[:id], :datebook_id => datebook.id).first
    
    # if "as_values_patient_id" is not empty use that, otherwise use "patient_id"
    if params[:appointment][:patient_id] != nil
      params[:appointment][:patient_id] = Patient.find_or_create_from((params[:as_values_patient_id] != "") ? (params[:as_values_patient_id]) : (params[:appointment][:patient_id]))
    end
    
    respond_to do |format|
      if @appointment.update_attributes(params[:appointment])
        format.js { } # update.js.erb
      else
        format.js  { 
          render_ujs_error(@appointment, I18n.t(:appointment_updated_error_message))
        }
      end
    end
  end
  
  def destroy
    datebook = Datebook.mine.find params[:datebook_id]
    @appointment = Appointment.where(:id => params[:id], :datebook_id => datebook.id).first

    respond_to do |format|
      if @appointment.destroy
          format.js { render :action => :create } # reuses create.js.erb
      else
          format.js  {
            render_ujs_error(@appointment, I18n.t(:appointment_deleted_error_message))
          }
      end
    end
  end

end
