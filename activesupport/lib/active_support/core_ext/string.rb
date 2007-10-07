require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/string/conversions'
require 'active_support/core_ext/string/access'
require 'active_support/core_ext/string/starts_ends_with'
require 'active_support/core_ext/string/iterators' unless 'test'.respond_to?(:each_char)
require 'active_support/core_ext/string/unicode'
require 'active_support/core_ext/string/xchar'

class String #:nodoc:
  include ActiveSupport::CoreExtensions::String::Access
  include ActiveSupport::CoreExtensions::String::Conversions
  include ActiveSupport::CoreExtensions::String::Inflections
  include ActiveSupport::CoreExtensions::String::StartsEndsWith
  if defined? ActiveSupport::CoreExtensions::String::Iterators
    include ActiveSupport::CoreExtensions::String::Iterators
  end
  include ActiveSupport::CoreExtensions::String::Unicode
end
