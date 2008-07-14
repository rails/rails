%w(keys indifferent_access deep_merge reverse_merge conversions diff slice except).each do |ext|
  require "active_support/core_ext/hash/#{ext}"
end

class Hash #:nodoc:
  include ActiveSupport::CoreExtensions::Hash::Keys
  include ActiveSupport::CoreExtensions::Hash::IndifferentAccess
  include ActiveSupport::CoreExtensions::Hash::DeepMerge
  include ActiveSupport::CoreExtensions::Hash::ReverseMerge
  include ActiveSupport::CoreExtensions::Hash::Conversions
  include ActiveSupport::CoreExtensions::Hash::Diff
  include ActiveSupport::CoreExtensions::Hash::Slice
  include ActiveSupport::CoreExtensions::Hash::Except
end
