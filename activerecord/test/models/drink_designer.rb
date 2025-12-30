# frozen_string_literal: true

class DrinkDesigner < ActiveRecord::Base
  has_one :chef, as: :employable
  accepts_nested_attributes_for :chef
end

class DrinkDesignerWithPolymorphicDependentNullifyChef < ActiveRecord::Base
  self.table_name = "drink_designers"

  has_one :chef, as: :employable, dependent: :nullify
end

class DrinkDesignerWithPolymorphicTouchChef < ActiveRecord::Base
  self.table_name = "drink_designers"

  has_one :chef, as: :employable, touch: true
end

class MocktailDesigner < DrinkDesigner
end
