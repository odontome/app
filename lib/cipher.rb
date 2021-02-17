# frozen_string_literal: true

class Cipher
  def self.decode(string)
    cipher = Gibberish::AES.new(Rails.application.secrets.secret_key_base)
    encrypted = Base64.strict_decode64(string)
    cipher.decrypt(encrypted)
  end

  def self.encode(string)
    cipher = Gibberish::AES.new(Rails.application.secrets.secret_key_base)
    encrypted = cipher.encrypt(string)
    Base64.strict_encode64(encrypted)
  end
end
