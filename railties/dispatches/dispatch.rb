#!/usr/local/bin/ruby

require File.dirname(__FILE__) + "/../config/environments/production"
require 'dispatcher'

ADDITIONAL_LOAD_PATHS.each { |dir| $:.unshift "#{File.dirname(__FILE__)}/../#{dir}" }
Dispatcher.dispatch