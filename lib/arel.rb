require 'active_support/inflector'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/class/attribute_accessors'

require 'active_record'
require 'active_record/connection_adapters/abstract/quoting'

$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'arel/algebra'
require 'arel/engines'
require 'arel/session'
