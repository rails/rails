# encoding: utf-8

require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/string/bytesize'
require 'active_support/core_ext/string/conversions'
require 'active_support/core_ext/string/access'
require 'active_support/core_ext/string/starts_ends_with'
require 'active_support/core_ext/string/iterators'
require 'active_support/core_ext/string/multibyte'
require 'active_support/core_ext/string/xchar'
require 'active_support/core_ext/string/filters'
require 'active_support/core_ext/string/behavior'
require 'active_support/core_ext/string/output_safety'

class String #:nodoc:
  include ActiveSupport::CoreExtensions::String::Access
  include ActiveSupport::CoreExtensions::String::Conversions
  include ActiveSupport::CoreExtensions::String::Filters
  include ActiveSupport::CoreExtensions::String::Inflections
  include ActiveSupport::CoreExtensions::String::StartsEndsWith
  include ActiveSupport::CoreExtensions::String::Iterators
  include ActiveSupport::CoreExtensions::String::Behavior
  include ActiveSupport::CoreExtensions::String::Multibyte
  include ActiveSupport::CoreExtensions::String::OutputSafety
end
