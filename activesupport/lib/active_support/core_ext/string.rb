require File.dirname(__FILE__) + '/string/inflections'
require File.dirname(__FILE__) + '/string/conversions'
require File.dirname(__FILE__) + '/string/access'
require File.dirname(__FILE__) + '/string/starts_ends_with'
require File.dirname(__FILE__) + '/string/iterators'
require File.dirname(__FILE__) + '/string/unicode'

class String #:nodoc:
  include ActiveSupport::CoreExtensions::String::Access
  include ActiveSupport::CoreExtensions::String::Conversions
  include ActiveSupport::CoreExtensions::String::Inflections
  include ActiveSupport::CoreExtensions::String::StartsEndsWith
  include ActiveSupport::CoreExtensions::String::Iterators
  include ActiveSupport::CoreExtensions::String::Unicode
end
