require 'cases/helper'

class ModelTest < ActiveModel::TestCase
  include ActiveModel::Lint::Tests

  class Racer
    include ActiveModel::BasicModel
    attr_accessor :name
  end

  def setup
    @model = Racer.new
  end

  def test_initialize_with_params
    racer = Racer.new(:name => "DHH")
    assert_equal racer.name, "DHH"
  end

  def test_initialize_with_nil_or_empty_hash_params_does_not_explode
    assert_nothing_raised do
      Racer.new()
      Racer.new({})
    end
  end
end
