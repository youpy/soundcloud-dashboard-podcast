require 'bundler'
require 'rack/test'
require 'webmock/rspec'

Bundler.require(:default, :test)

require File.dirname(__FILE__) + '/../server'

set :environment, :test

RSpec.configure do |config|
  def fixture(filename)
    File.dirname(__FILE__) + '/fixtures/' + filename
  end

  def read_fixture(filename)
    open(fixture(filename)).read
  end
end
