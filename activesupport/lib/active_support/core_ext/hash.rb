require File.dirname(__FILE__) + '/hash/keys'
require File.dirname(__FILE__) + '/hash/indifferent_access'

class Hash #:nodoc:
  include ActiveSupport::CoreExtensions::Hash::Keys
  include ActiveSupport::CoreExtensions::Hash::IndifferentAccess
end
