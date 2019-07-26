# frozen_string_literal: true

class DrinkDesigner < ActiveRecord::Base
  has_one :chef, as: :employable
end

class DrinkDesignerWithPolymorphicDependentNullifyChef < ActiveRecord::Base
  self.table_name = "drink_designers"

  has_one :chef, as: :employable, dependent: :nullify
end

class MocktailDesigner < DrinkDesigner
end
