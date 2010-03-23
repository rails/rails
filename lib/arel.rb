require 'active_support/inflector'
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/object/blank'

module Arel
  require 'arel/algebra'
  require 'arel/engines'
  require 'arel/version'

  autoload :Session, 'arel/session'
end
