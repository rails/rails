require File.dirname(__FILE__) + '/hash/keys'

class Hash
  include ActiveSupport::CoreExtensions::Hash::Keys
end
