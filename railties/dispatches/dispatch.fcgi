#!/usr/local/bin/ruby

require File.dirname(__FILE__) + "/../config/environment"
require 'dispatcher'
require 'fcgi'

FCGI.each_cgi { |cgi| Dispatcher.dispatch(cgi) }