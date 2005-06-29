#!/usr/local/bin/ruby

require File.dirname(__FILE__) + "/../config/environment"
require 'fcgi_handler'

RailsFCGIHandler.process!
