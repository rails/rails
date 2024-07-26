#!/usr/local/bin/ruby

require File.dirname(__FILE__) + '/../vendor/railties/load_path'
require 'dispatcher'
Dispatcher.new(File.dirname(__FILE__) + "/..").dispatch