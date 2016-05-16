class Property < ActiveRecord::Base
  has_many :units
  @scope_value = 0

  def self.default_scope
    where('scope_field = :scoper', scoper: @scope_value += 1)
  end
end

class PropertyWithBlock < ActiveRecord::Base
  has_many :units
  @scope_value = 0

  self.default_scope do
    where('scope_field = :scoper', scoper: @scope_value += 1)
  end
end
