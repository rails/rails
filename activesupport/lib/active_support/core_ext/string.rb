require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/string/conversions'
require 'active_support/core_ext/string/access'
require 'active_support/core_ext/string/starts_ends_with'
require 'active_support/core_ext/string/iterators'
require 'active_support/core_ext/string/unicode'
require 'active_support/core_ext/string/xchar'
require 'active_support/core_ext/string/filters'

class String #:nodoc:
  include ActiveSupport::CoreExtensions::String::Access
  include ActiveSupport::CoreExtensions::String::Conversions
  include ActiveSupport::CoreExtensions::String::Filters
  include ActiveSupport::CoreExtensions::String::Inflections
  include ActiveSupport::CoreExtensions::String::StartsEndsWith
  include ActiveSupport::CoreExtensions::String::Iterators
  include ActiveSupport::CoreExtensions::String::Unicode
end
