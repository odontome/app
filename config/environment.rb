# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Odontome::Application.initialize!

# FastGettext stuff
AVAILABLE_LOCALES = ['es-ES', 'en-US'] # only allow these locales to be set (optional)
PLANS = YAML.load_file(File.join(Rails.root, "config", "plans.yml"))

# Don't include the root object in the JSON 
ActiveRecord::Base.include_root_in_json = false
