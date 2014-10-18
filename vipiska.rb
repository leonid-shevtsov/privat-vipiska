require 'rubygems'
require 'bundler/setup'
require 'sinatra'

$:.unshift File.dirname(__FILE__)
require 'lib/crypto'
require 'lib/privatbank_client'

get '/' do
  haml :about
end

post '/encrypt' do
  encrypted_params = Crypto.encrypt_params(params)
  redirect to('/vipiska.csv?i=' + encrypted_params[:iv] + '&e=' + encrypted_params[:encrypted])
end

get '/vipiska.csv' do
  decrypted_params = Crypto.decrypt_params(params)
  headers "Content-Type" => "application/csv; charset=utf-8"
  PrivatbankClient.new(decrypted_params).vipiska_csv
end
