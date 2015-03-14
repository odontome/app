class Cipher
  def self.decode(string)
    cipher = Gibberish::AES.new(Rails.configuration.secret_token)
    cipher.dec(Base64.strict_decode64(string))
  end

  def self.encode(string)
    cipher = Gibberish::AES.new(Rails.configuration.secret_token)
    ciphered_url_encoded_id = Base64.strict_encode64(cipher.enc(string))
  end
end
