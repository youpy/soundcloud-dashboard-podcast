require 'rubygems'

require 'openssl'
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

require 'bundler'

Bundler.require

require './server'

run Sinatra::Application
