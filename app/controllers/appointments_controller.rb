class AppointmentsController < ApplicationController
  # filters
  before_filter :require_user
  
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
    @datebook = Datebook.mine.find params[:datebook_id]
    @appointment = Appointment.where(:id => params[:id], :datebook_id => @datebook.id).first

    pass = Passbook::PKPass.new '{
                "formatVersion" : 1,
                "passTypeIdentifier" : "pass.com.raulriera.odontome.web",
                "serialNumber" : "'+@appointment.id.to_s+'",
                "teamIdentifier" : "R64MTWS872",
                "organizationName" : "Odonto.me",
                "description" : "Coupon for 1 Free Hug",
                "logoText" : "",
                "foregroundColor" : "#ffffff",
                "backgroundColor" : "#3389d1",
                "relevantDate" : "' + @appointment.starts_at.to_formatted_s(:date) + '",
                "barcode" : {
                    "message" : "http://my.odonto.me/appointments/' + @appointment.id.to_s + '/check-in",
                    "format" : "PKBarcodeFormatQR",
                    "messageEncoding" : "iso-8859-1"
                },
                "eventTicket": {
                   "primaryFields" : [
                        {
                       "key" : "location",
                       "label" : "Practice",
                       "value" :  "' + @datebook.practice.name + '"
                       }
                   ],
                   "auxiliaryFields" : [
                      {
                       "key" : "date",
                       "label" : "Date",
                       "value" : "' + l(@appointment.starts_at.to_date, :format => :day_and_date) + ' ' + @appointment.starts_at.to_formatted_s(:time) + '"
                       },
                       {
                       "key" : "doctor",
                       "label" : "Doctor",
                       "value" : "' + @appointment.doctor.fullname + '"
                       }
                   ],
                   "backFields" : [
                      {
                        "key" : "extras",
                        "label" : "Extras",
                        "value" : "Your friends receive 50% off price"
                      },
                      {
                        "key" : "phone",
                        "label" : "For more info",
                        "value" : "800-1234567890"
                      },
                      {
                        "key" : "terms",
                        "label" : "TERMS AND CONDITIONS",
                        "value" : "Free hugs last 18 seconds and must be claimed on your birthday. Bring your pass or an id"
                      }
                    ]
                }
            }'

    pass.addFiles ['passbook/logo.png', 'passbook/logo@2x.png', 'passbook/icon.png', 'passbook/icon@2x.png']

    pkpass = pass.stream
    send_data pkpass.string, type: 'application/vnd.apple.pkpass', disposition: 'attachment', filename: "pass.pkpass"

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
