require File.dirname(__FILE__) + '/hash/keys'

class Hash #:nodoc:
  include ActiveSupport::CoreExtensions::Hash::Keys
end
