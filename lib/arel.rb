$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'activesupport'
require 'activerecord'
require 'active_record/connection_adapters/abstract/quoting'

require 'arel/algebra'
require 'arel/engines'
require 'arel/session'
