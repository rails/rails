$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'activesupport'
require 'activerecord'

require 'active_relation/sql_builder'

require 'active_relation/extensions/object'
require 'active_relation/extensions/array'
require 'active_relation/extensions/base'
require 'active_relation/extensions/hash'

require 'active_relation/relations'
require 'active_relation/predicates'