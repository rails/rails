require 'active_support/inflector'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/class/attribute_accessors'

require 'active_record'
require 'active_record/connection_adapters/abstract/quoting'

module Arel
  require 'arel/algebra'
  require 'arel/engines'
  autoload :Session, 'arel/session'

  VERSION = "0.2.pre"
end