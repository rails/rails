# frozen_string_literal: true

require "cases/helper"

class APITest < ActiveModel::TestCase
  include ActiveModel::Lint::Tests

  module DefaultValue
    def self.included(klass)
      klass.class_eval { attr_accessor :hello }
    end

    def initialize(*args)
      @attr ||= "default value"
      super
    end
  end

  class BasicModel
    include DefaultValue
    include ActiveModel::API
    attr_accessor :attr
  end

  class BasicModelWithReversedMixins
    include ActiveModel::API
    include DefaultValue
    attr_accessor :attr
  end

  class SimpleModel
    include ActiveModel::API
    attr_accessor :attr
  end

  def setup
    @model = BasicModel.new
  end

  def test_initialize_with_params
    object = BasicModel.new(attr: "value")
    assert_equal "value", object.attr
  end

  def test_initialize_with_params_and_mixins_reversed
    object = BasicModelWithReversedMixins.new(attr: "value")
    assert_equal "value", object.attr
  end

  def test_initialize_with_nil_or_empty_hash_params_does_not_explode
    assert_nothing_raised do
      BasicModel.new()
      BasicModel.new(nil)
      BasicModel.new({})
      SimpleModel.new(attr: "value")
    end
  end

  def test_persisted_is_always_false
    object = BasicModel.new(attr: "value")
    assert_not object.persisted?
  end

  def test_mixin_inclusion_chain
    object = BasicModel.new
    assert_equal "default value", object.attr
  end

  def test_mixin_initializer_when_args_exist
    object = BasicModel.new(hello: "world")
    assert_equal "world", object.hello
  end

  def test_mixin_initializer_when_args_dont_exist
    assert_raises(ActiveModel::UnknownAttributeError) do
      SimpleModel.new(hello: "world")
    end
  end
end
