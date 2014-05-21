require 'bundler'
Bundler.setup

$LOAD_PATH << File.dirname(__FILE__) + "/../lib"

require 'active_job'
require "adapters/#{ENV['AJADAPTER'] || 'inline'}"

puts "Testing using #{ENV['AJADAPTER'] || 'inline'}"
require 'active_support/testing/autorun'


ActiveJob::Base.logger.level = Logger::ERROR
