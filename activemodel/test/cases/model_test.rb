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
end
