# frozen_string_literal: true

class Cipher
  KEY = Gibberish::AES.new(Rails.application.secret_key_base)

  def self.decode(string)
    cipher = KEY
    decrypted = Base64.strict_decode64(string)
    cipher.decrypt(decrypted)
  end

  def self.encode(string)
    cipher = KEY
    encrypted = cipher.encrypt(string)
    Base64.strict_encode64(encrypted)
  end
end
