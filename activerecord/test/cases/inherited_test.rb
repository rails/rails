# frozen_string_literal: true

require "cases/helper"

module Inherited
  # When running the test with `RAILS_STRICT_WARNINGS` enabled, the `belongs_to`
  # call should not emit a warning that the constant `GeneratedAssociationMethods`
  # is already defined.
  class Person < ActiveRecord::Base; end

  class Device < ActiveRecord::Base
    def self.inherited(subclass)
      subclass.belongs_to :person, inverse_of: subclass.name.demodulize.tableize.to_sym
      subclass.filter_attributes = [:secret_attribute, :"#{subclass.name.demodulize.downcase}_key"]
      super
    end
  end

  class Computer < Device; end

  class Vehicle < ActiveRecord::Base
    def self.inherited(subclass)
      super
      subclass.belongs_to :person, inverse_of: subclass.name.demodulize.tableize.to_sym
      subclass.filter_attributes = [:secret_attribute, :"#{subclass.name.demodulize.downcase}_key"]
    end
  end

  class Car < Vehicle; end
end

class InheritedTest < ActiveRecord::TestCase
  def test_super_before_filter_attributes
    assert_equal %i[secret_attribute car_key], Inherited::Car.filter_attributes
  end

  def test_super_after_filter_attributes
    assert_equal %i[secret_attribute computer_key], Inherited::Computer.filter_attributes
  end
end
