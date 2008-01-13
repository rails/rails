$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'activesupport'
require 'activerecord'

require 'active_relation/sql_builder'
require 'active_relation/extensions'
require 'active_relation/predicates'
require 'active_relation/relations'
require 'active_relation/primitives'