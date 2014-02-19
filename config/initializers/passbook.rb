require 'passbook'

Passbook.configure do |passbook|
  passbook.wwdc_cert = File.join(Rails.root, "passbook", "WWDR.pem")
  passbook.p12_key = File.join(Rails.root, "passbook", "passkey.pem")
  passbook.p12_certificate = File.join(Rails.root, "passbook", "passcertificate.pem")
  passbook.p12_password = 'dunces216!zapped'
end