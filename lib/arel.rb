$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'activesupport'
require 'activerecord'
require 'active_record/connection_adapters/abstract/quoting'

require 'arel/arel'
require 'arel/extensions'
require 'arel/predicates'
require 'arel/relations'
require 'arel/engines'
require 'arel/session'
require 'arel/primitives'
