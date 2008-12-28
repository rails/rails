$LOAD_PATH.unshift File.dirname(__FILE__)

require "core_ext/blank"
# whole object.rb pulls up rare used introspection extensions
require "core_ext/object/metaclass"
require 'core_ext/array'
require 'core_ext/hash'
require 'core_ext/module/attribute_accessors'
require 'multibyte'
require 'core_ext/string/multibyte'
require 'core_ext/string/inflections'

class String
  include ActiveSupport::CoreExtensions::String::Multibyte
end
