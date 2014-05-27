require 'mixpanel-ruby'

if Rails.env.development? || Rails.env.test?
  MIXPANEL_CLIENT = Mixpanel::Tracker.new("ea0b61ee9bb501bf0ff98740f0a4b0e2")
else
  MIXPANEL_CLIENT = Mixpanel::Tracker.new("a11e3dace9deabb780160e4acde44863")
end
