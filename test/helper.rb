require 'bundler'
Bundler.setup

$LOAD_PATH << File.dirname(__FILE__) + "/../lib"

require 'active_job'

adapter  = ENV['AJADAPTER'] || 'inline'
require "adapters/#{adapter}"
puts "Testing using #{adapter}"

require 'active_support/testing/autorun'


ActiveJob::Base.logger.level = Logger::ERROR
