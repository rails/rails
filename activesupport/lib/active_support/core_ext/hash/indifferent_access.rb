require 'active_support/hash_with_indifferent_access'

class Hash

  # Returns an +ActiveSupport::HashWithIndifferentAccess+ out of its receiver:
  #
  #   {:a => 1}.with_indifferent_access["a"] # => 1
  #
  def with_indifferent_access
    ActiveSupport::HashWithIndifferentAccess.new_from_hash_copying_default(self)
  end
end
