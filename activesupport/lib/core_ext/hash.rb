$:.unshift(File.dirname(__FILE__))
require 'hash/keys'

class Hash
  include ActiveSupport::CoreExtensions::Hash::Keys
end
