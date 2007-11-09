$LOAD_PATH << File.join(File.dirname(__FILE__), '..', '..', 'activesupport', 'lib')

# premature optimization?
require 'active_support/inflector'
require 'active_support/core_ext/string/inflections'
String.send :include, ActiveSupport::CoreExtensions::String::Inflections

require 'active_model/base'
require 'active_model/observing'
require 'active_model/callbacks'
require 'active_model/validations'

ActiveModel::Base.class_eval do
  include ActiveModel::Observing
  include ActiveModel::Callbacks
  include ActiveModel::Validations
end