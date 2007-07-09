%w(keys indifferent_access reverse_merge conversions diff slice except).each do |ext|
  require "#{File.dirname(__FILE__)}/hash/#{ext}"
end

class Hash #:nodoc:
  include ActiveSupport::CoreExtensions::Hash::Keys
  include ActiveSupport::CoreExtensions::Hash::IndifferentAccess
  include ActiveSupport::CoreExtensions::Hash::ReverseMerge
  include ActiveSupport::CoreExtensions::Hash::Conversions
  include ActiveSupport::CoreExtensions::Hash::Diff
  include ActiveSupport::CoreExtensions::Hash::Slice
  include ActiveSupport::CoreExtensions::Hash::Except
end
