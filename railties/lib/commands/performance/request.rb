#!/usr/bin/env ruby
RAILS_DEFAULT_LOGGER = nil
require 'config/environment'
require 'application'
require 'action_controller/request_profiler'

ActionController::RequestProfiler.run(ARGV)
