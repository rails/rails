#!/usr/bin/env ruby
require 'config/environment'
require 'application'
require 'action_controller/request_profiler'

ActionController::RequestProfiler.run(ARGV)
