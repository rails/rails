require 'bundler'
Bundler.setup

$LOAD_PATH << File.dirname(__FILE__) + "/../lib"

require 'active_job'

adapter  = ENV['AJADAPTER'] || 'inline'
puts "Testing#{" integration" if ENV['AJ_INTEGRATION_TESTS']} using #{adapter}"

if ENV['AJ_INTEGRATION_TESTS']
  require 'support/integration/helper'
else
  require "adapters/#{adapter}"
end

require 'active_support/testing/autorun'

ActiveJob::Base.logger.level = Logger::DEBUG
