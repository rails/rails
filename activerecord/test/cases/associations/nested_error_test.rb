# frozen_string_literal: true

require "cases/helper"
require "models/guitar"
require "models/tuning_peg"

class AssociationsNestedErrorInAssociationOrderTest < ActiveRecord::TestCase
  test "index in association order" do
    guitar = Guitar.create!
    guitar.tuning_pegs.create!(pitch: 1)
    peg2 = guitar.tuning_pegs.create!(pitch: 2)
    peg2.pitch = nil
    guitar.valid?

    error = guitar.errors.objects.first

    assert_equal ActiveRecord::Associations::NestedError, error.class
    assert_equal peg2.errors.objects.first, error.inner_error
    assert_equal :'tuning_pegs[1].pitch', error.attribute
    assert_equal :not_a_number, error.type
    assert_equal "is not a number", error.message
    assert_equal guitar, error.base
  end
end

class AssociationsNestedErrorInNestedAttributesOrderTest < ActiveRecord::TestCase
  def setup
    tuning_peg_class = Class.new(ActiveRecord::Base) do
      self.table_name = "tuning_pegs"
      def self.name; "TuningPeg"; end

      validates_numericality_of :pitch
    end

    @guitar_class = Class.new(ActiveRecord::Base) do
      has_many :tuning_pegs, index_errors: :nested_attributes_order, anonymous_class: tuning_peg_class
      accepts_nested_attributes_for :tuning_pegs, reject_if: lambda { |attrs| attrs[:pitch]&.odd? }

      def self.name; "Guitar"; end
    end
  end

  test "index in nested attributes order" do
    guitar = @guitar_class.create!
    guitar.tuning_pegs.create!(pitch: 1)
    peg2 = guitar.tuning_pegs.create!(pitch: 2)
    guitar.update(tuning_pegs_attributes: [{ id: peg2.id, pitch: nil }])

    error = guitar.errors.objects.first

    assert_equal ActiveRecord::Associations::NestedError, error.class
    assert_equal peg2.errors.objects.first, error.inner_error
    assert_equal :'tuning_pegs[0].pitch', error.attribute
    assert_equal :not_a_number, error.type
    assert_equal "is not a number", error.message
    assert_equal guitar, error.base
  end

  test "index unaffected by reject_if" do
    guitar = @guitar_class.create!

    guitar.update(
      tuning_pegs_attributes: [
        { pitch: 1 }, # rejected
        { pitch: nil },
      ]
    )

    error = guitar.errors.objects.first

    assert_equal ActiveRecord::Associations::NestedError, error.class
    assert_equal :'tuning_pegs[1].pitch', error.attribute
    assert_equal :not_a_number, error.type
    assert_equal "is not a number", error.message
    assert_equal guitar, error.base
  end
end
