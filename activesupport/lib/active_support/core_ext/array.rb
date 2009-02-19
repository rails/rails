require 'active_support/core_ext/array/access'
require 'active_support/core_ext/array/conversions'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/array/grouping'
require 'active_support/core_ext/array/random_access'
require 'active_support/core_ext/array/wrapper'

class Array #:nodoc:
  include ActiveSupport::CoreExtensions::Array::Access
  include ActiveSupport::CoreExtensions::Array::Conversions
  include ActiveSupport::CoreExtensions::Array::ExtractOptions
  include ActiveSupport::CoreExtensions::Array::Grouping
  include ActiveSupport::CoreExtensions::Array::RandomAccess
  extend ActiveSupport::CoreExtensions::Array::Wrapper
end
