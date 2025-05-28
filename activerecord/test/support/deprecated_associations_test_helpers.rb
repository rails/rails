module DeprecatedAssociationsTestHelpers
  def self.included(base)
    base.const_set(:Car, Car)
    base.const_set(:Tyre, Tyre)
    base.const_set(:Bulb, Bulb)
  end

  def self.table_name_prefix
    ''
  end

  SELF = self

  class Car < ActiveRecord::Base
    self.lock_optimistically = false

    has_many :tyres, class_name: "#{SELF}::Tyre", dependent: :destroy
    has_many :deprecated_tyres, class_name: "#{SELF}::Tyre", dependent: :destroy, deprecated: true

    accepts_nested_attributes_for :tyres, :deprecated_tyres

    has_one :bulb, class_name: "#{SELF}::Bulb", dependent: :destroy
    has_one :deprecated_bulb, class_name: "#{SELF}::Bulb", dependent: :destroy, deprecated: true

    accepts_nested_attributes_for :bulb, :deprecated_bulb
  end

  class Tyre < ActiveRecord::Base
  end

  class Bulb < ActiveRecord::Base
    belongs_to :car, class_name: "#{SELF}::Car", dependent: :destroy, touch: true
    belongs_to :deprecated_car, class_name: "#{SELF}::Car", foreign_key: "car_id", dependent: :destroy, touch: true, deprecated: true
  end

  private
    def assert_deprecated_association(association, model = @model, &)
      asserted = false
      mock = ->(reflection) do
        if reflection.active_record == model && reflection.name == association
          asserted = true
        end
      end
      ActiveRecord::Associations::Deprecation.stub(:notify, mock, &)
      assert asserted, "Expected a deprecation notification for #{model}##{association}, but got none"
    end

    def assert_not_deprecated_association(association, model = @model, &)
      mock = ->(reflection) do
        if reflection.active_record == model && reflection.name == association
          raise Minitest::Assertion, "Got a deprecation notification for #{model}##{association}, but expected none"
        end
      end
      ActiveRecord::Associations::Deprecation.stub(:notify, mock, &)
    end
end
