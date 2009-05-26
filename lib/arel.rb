$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'activesupport'
require 'active_support/dependencies'
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/module/delegation'
require 'activerecord'
require 'active_record/connection_adapters/abstract/quoting'

require 'arel/algebra'
require 'arel/engines'
require 'arel/session'
