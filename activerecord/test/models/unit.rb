require 'models/property'

class Unit < ActiveRecord::Base
  belongs_to :property

  def self.with_active_properties
    joins(:property)
  end
end

class UnitWithBlock < ActiveRecord::Base
  belongs_to :property, class_name: PropertyWithBlock

  def self.with_active_properties
    joins(:property)
  end
end
