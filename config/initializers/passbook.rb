require 'passbook'

Passbook.configure do |passbook|
  # Path to your wwdc cert file
  passbook.wwdc_cert = File.join(Rails.root, "apple-cert", "AppleWWDRCA.pem")

  # Path to your cert.p12 file
  passbook.p12_cert = File.join(Rails.root, "apple-cert", "Certificate.p12")
  
  # Password for your certificate
  passbook.p12_password = 'dunces216!zapped'
end