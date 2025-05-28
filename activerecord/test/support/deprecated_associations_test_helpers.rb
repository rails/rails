require "active_record"
require "active_record/base"

module DeprecatedAssociationsTestHelpers
  NS = self

  def self.included(base)
    base.fixtures(:cars)

    base.const_set(:Car, Car)
    base.const_set(:Tyre, Tyre)
  end

  def self.table_name_prefix
    ''
  end

  class Car < ActiveRecord::Base
    has_many :tyres, class_name: "#{NS}::Tyre", dependent: :destroy
    has_many :deprecated_tyres, class_name: "#{NS}::Tyre", dependent: :destroy, deprecated: true
  end

  class Tyre < ActiveRecord::Base
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
