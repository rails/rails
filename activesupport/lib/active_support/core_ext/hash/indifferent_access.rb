require 'active_support/hash_with_indifferent_access'

class Hash
  def with_indifferent_access
    hash = ActiveSupport::HashWithIndifferentAccess.new(self)
    hash.default = self.default
    hash
  end
end
