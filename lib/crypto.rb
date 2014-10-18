require 'yaml'
require 'base64'
require 'cgi'

module Crypto
  VIPISKA_SETTINGS = YAML.load_file('settings.yml')

  class << self

    def encrypt_params(params)
      cipher = OpenSSL::Cipher.new('AES-128-CBC')
      cipher.encrypt
      cipher.key = Base64.decode64(VIPISKA_SETTINGS[:key])
      iv = cipher.random_iv
      params_string = [params[:card], params[:merchant_id], params[:password]].join('|')
      encrypted = cipher.update(params_string) + cipher.final
      {iv: CGI::escape(Base64.urlsafe_encode64(iv)), encrypted: CGI::escape(Base64.urlsafe_encode64(encrypted))}
    end

    def decrypt_params(params)
      cipher = OpenSSL::Cipher.new('AES-128-CBC')
      cipher.decrypt
      cipher.key = Base64.decode64(VIPISKA_SETTINGS[:key])
      cipher.iv = Base64.urlsafe_decode64(params[:i])
      decrypted = cipher.update(Base64.urlsafe_decode64(params[:e])) + cipher.final
      decrypted_params = {}
      decrypted_params[:card], decrypted_params[:merchant_id], decrypted_params[:password] = decrypted.split('|')
      decrypted_params
    end
  end
end
