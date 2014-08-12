require File.expand_path('../../../load_paths', __FILE__)

require 'active_job'

adapter  = ENV['AJADAPTER'] || 'inline'

require "adapters/#{adapter}"

require 'active_support/testing/autorun'

ActiveJob::Base.logger.level = Logger::DEBUG
