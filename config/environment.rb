# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Odontome::Application.initialize!

# FastGettext stuff
AVAILABLE_LOCALES = ['es-ES', 'en-US'] # only allow these locales to be set (optional)
PLANS = YAML.load_file(File.join(Rails.root, "config", "plans.yml"))
