#!/usr/local/bin/ruby

require File.dirname(__FILE__) + '/../vendor/railties/load_path'
require 'dispatcher'
require 'fcgi'

dispatcher = Dispatcher.new(File.dirname(__FILE__) + "/..")
FCGI.each_cgi{ |cgi| dispatcher.dispatch(cgi) }