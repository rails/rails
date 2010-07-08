class LoosePerson < ActiveRecord::Base
  self.table_name = 'people'
  self.abstract_class = true

  attr_protected :credit_rating, :administrator
end

class LooseDescendant < LoosePerson
  attr_protected :phone_number
end

class LooseDescendantSecond< LoosePerson
  attr_protected :phone_number
  attr_protected :name
end

class TightPerson < ActiveRecord::Base
  self.table_name = 'people'
  attr_accessible :name, :address
end

class TightDescendant < TightPerson
  attr_accessible :phone_number
end