require 'active_support/hash_with_indifferent_access'

class Hash

  # Returns an +ActiveSupport::HashWithIndifferentAccess+ out of its receiver:
  #
  #   {:a => 1}.with_indifferent_access["a"] # => 1
  #
  def with_indifferent_access
    hash = ActiveSupport::HashWithIndifferentAccess.new(self)
    hash.default = self.default
    hash
  end
end
