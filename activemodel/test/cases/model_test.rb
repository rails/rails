# frozen_string_literal: true

require "cases/helper"

class ModelTest < ActiveModel::TestCase
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
    include ActiveModel::Model
    self.filter_attributes = %w[
      filtered_attr
    ]
    attr_accessor :attr
    attr_accessor :filtered_attr
  end

  class BasicModelAttributes
    include DefaultValue
    include ActiveModel::Model
    self.filter_attributes = %w[
      filtered_attr
    ]
    attribute :attr, :string
    attribute :filtered_attr, :string
  end

  class BasicModelWithReversedMixins
    include ActiveModel::Model
    include DefaultValue
    attr_accessor :attr
  end

  class SimpleModel
    include ActiveModel::Model
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

  def test_filtered_attributes_are_masked
    [
      BasicModel,
      BasicModelAttributes,
    ].each do |klass|
      object = klass.new(attr: "value", filtered_attr: "filtered value")
      assert_equal "value", object.attr
      assert_equal "filtered value", object.filtered_attr
      assert_equal %(<#{klass.name} attr="value", filtered_attr="[FILTERED]">), object.inspect
    end
  end

  def test_load_hook_is_called
    value = "not loaded"

    ActiveSupport.on_load(:active_model) { value = "loaded" }

    assert_equal "loaded", value
  end
end
