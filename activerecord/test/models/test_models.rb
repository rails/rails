class Listing < ActiveRecord::Base
  belongs_to :building, autosave: true
end

class Building < ActiveRecord::Base
  has_many :sales, autosave: true
  has_many :expenses, autosave: true
end
  
class Expense < ActiveRecord::Base
  belongs_to :building, autosave: true
end

class Sale < ActiveRecord::Base
  belongs_to :building, autosave: true
end



class Child < ActiveRecord::Base
  belongs_to :parent, inverse_of: :child, autosave: true
end



class Grandparent < ActiveRecord::Base
  has_one :parent, inverse_of: :grandparent, autosave: true
end


class Parent < ActiveRecord::Base
  has_one :child, inverse_of: :parent, autosave: true
  belongs_to :grandparent, inverse_of: :parent, autosave: true

  @@after_save_foo = 0
  @@after_validation_foo = 0

  after_save  -> { @@after_save_foo += 1 }
  after_validation -> { @@after_validation_foo += 1 }

end
__END__
# frozen_string_literal: true

class Survey < ActiveRecord::Base
  has_many :listings, -> { order(order: :asc) }, inverse_of: :survey, dependent: :destroy, autosave: true
end

class Listing < ActiveRecord::Base
  belongs_to :building, dependent: :destroy, autosave: true
  belongs_to :survey, optional: true, inverse_of: :listings, autosave: true
  has_many :units, -> {order(order: :asc)}, inverse_of: :listing, dependent: :destroy, autosave: true
end

class Building < ActiveRecord::Base
  has_many :listings, autosave: true
  has_many :units, autosave: true
  has_and_belongs_to_many :addresses, autosave: true
end
  
class Address < ActiveRecord::Base
  has_and_belongs_to_many :buildings, inverse_of: :addresses, autosave: true
end

class Unit < ActiveRecord::Base
  belongs_to :building, autosave: true
  belongs_to :listing, inverse_of: :units, optional: true, autosave: true
end

survey = Survey.create
listing = Listing.new({
  building: Building.new({
    name: name,
    addresses: [a]
  })
})
listing.units << Unit.new(building: listing.building)

  
survey << listing



