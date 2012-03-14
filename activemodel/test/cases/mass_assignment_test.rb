require 'cases/helper'

class MassAssignmentTest < ActiveModel::TestCase
  class Model
    include ActiveModel::MassAssignment
    attr_accessor :attr
  end

  def setup
    @model = Model.new
  end

  def test_initialize_with_params
    object = Model.new(:attr => "value")
    assert_equal object.attr, "value"
  end

  def test_initialize_with_nil_or_empty_hash_params_does_not_explode
    assert_nothing_raised do
      Model.new()
      Model.new({})
    end
  end
end
