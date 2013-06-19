require 'cases/helper'

class ModelTest < ActiveModel::TestCase
  include ActiveModel::Lint::Tests

  module DefaultValue
    def self.included(klass)
      klass.class_eval { attr_accessor :hello }
    end

    def initialize(*args)
      @attr ||= 'default value'
    end
  end

  class BasicModel
    include DefaultValue
    include ActiveModel::Model
    attr_accessor :attr
  end

  class SimpleModel
    include ActiveModel::Model
  end

  def setup
    @model = BasicModel.new
  end

  def test_initialize_with_params
    object = BasicModel.new(attr: "value")
    assert_equal "value", object.attr
  end

  def test_initialize_with_nil_or_empty_hash_params_does_not_explode
    assert_nothing_raised do
      BasicModel.new()
      BasicModel.new nil
      BasicModel.new({})
    end
  end

  def test_persisted_is_always_false
    object = BasicModel.new(attr: "value")
    assert object.persisted? == false
  end

  def test_mixin_inclusion_chain
    object = BasicModel.new
    assert_equal 'default value', object.attr
  end

  def test_mixin_initializer_when_args_exist
    object = BasicModel.new(hello: 'world')
    assert_equal 'world', object.hello
  end

  def test_mixin_initializer_when_args_dont_exist
    assert_raises(NoMethodError) { SimpleModel.new(hello: 'world') }
  end

  def test_mixin_when_no_ancestors
    assert SimpleModel.new
  end
end
