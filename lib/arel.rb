$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'active_support'
require 'active_support/core_ext'
require 'activerecord'
require 'active_record/connection_adapters/abstract/quoting'

require 'arel/arel'
require 'arel/extensions'
require 'arel/sql'
require 'arel/predicates'
require 'arel/relations'
require 'arel/engine'
require 'arel/session'
require 'arel/primitives'
