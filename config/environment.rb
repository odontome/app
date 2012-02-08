$payments = false

# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Odontome::Application.initialize!

# FastGettext stuff
AVAILABLE_LOCALES = ['es-ES', 'en-US'] # only allow these locales to be set (optional)

# YAML config files
PLANS = YAML.load_file(File.join(Rails.root, "config", "plans.yml"))
TREATMENTS = YAML.load_file(File.join(Rails.root, "config", "treatments.yml"))

# Don't include the root object in the JSON 
ActiveRecord::Base.include_root_in_json = false

# Appointment notifications configuration
$appointment_notificacion_hours = 48 # if the appointment is in the next {hours} it will send a notification
$appointment_notificacion_time = 3 # UTC hours. Example: "3" for 3am-UTC

# Config authlogic
Authlogic::Session::Base.controller = Authlogic::ControllerAdapters::RailsAdapter.new(self)

# Overwrite the error messages
ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|
  %(<div class="form-field error">#{html_tag}</div>).html_safe
end

# Require the model extensions
require 'extensions/model_extensions'
