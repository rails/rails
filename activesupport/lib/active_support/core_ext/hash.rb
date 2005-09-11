require File.dirname(__FILE__) + '/hash/keys'
require File.dirname(__FILE__) + '/hash/indifferent_access'
require File.dirname(__FILE__) + '/hash/reverse_merge'

class Hash #:nodoc:
  include ActiveSupport::CoreExtensions::Hash::Keys
  include ActiveSupport::CoreExtensions::Hash::IndifferentAccess
  include ActiveSupport::CoreExtensions::Hash::ReverseMerge
end
