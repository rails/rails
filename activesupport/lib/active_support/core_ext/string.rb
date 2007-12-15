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
  if RUBY_VERSION < '1.9'
    include ActiveSupport::CoreExtensions::String::StartsEndsWith
  else
    alias starts_with? start_with?
    alias ends_with? end_with?
  end
  if defined? ActiveSupport::CoreExtensions::String::Iterators
    include ActiveSupport::CoreExtensions::String::Iterators
  end
  include ActiveSupport::CoreExtensions::String::Unicode
end
