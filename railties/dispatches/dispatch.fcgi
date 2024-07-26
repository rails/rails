#!/usr/local/bin/ruby

require File.dirname(__FILE__) + '/../vendor/railties/configs/load_path'
require 'dispatcher'
require 'fcgi'

FCGI.each_cgi{ |cgi| Dispatcher.dispatch(cgi) }