require 'cases/helper'

class ModelTest < ActiveModel::TestCase
  include ActiveModel::Lint::Tests

  class BasicModel
    include ActiveModel::Model
    attr_accessor :attr
  end

  def setup
    @model = BasicModel.new
  end

  def test_initialize_with_params
    object = BasicModel.new(:attr => "value")
    assert_equal object.attr, "value"
  end

  def test_initialize_with_nil_or_empty_hash_params_does_not_explode
    assert_nothing_raised do
      BasicModel.new()
      BasicModel.new({})
    end
  end
end
