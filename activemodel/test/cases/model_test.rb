require 'cases/helper'

class ModelTest < ActiveModel::TestCase
  include ActiveModel::Lint::Tests

  module DefaultValue
    def self.included(klass)
      klass.class_eval { attr_accessor :hello }
    end

    def initialize(*args)
      @attr ||= 'default value'
      super
    end
  end

  class BasicModel
    include DefaultValue
    include ActiveModel::Model
    attr_accessor :attr
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

  test "initialize with params" do
    object = BasicModel.new(attr: "value")
    assert_equal "value", object.attr
  end

  test "initialize with params and mixins reversed" do
    object = BasicModelWithReversedMixins.new(attr: "value")
    assert_equal "value", object.attr
  end

  test "initialize with nil or empty hash params does not explode" do
    assert_nothing_raised do
      BasicModel.new()
      BasicModel.new(nil)
      BasicModel.new({})
      SimpleModel.new(attr: 'value')
    end
  end

  test "persisted is always false" do
    object = BasicModel.new(attr: "value")
    assert object.persisted? == false
  end

  test "mixin inclusion chain" do
    object = BasicModel.new
    assert_equal 'default value', object.attr
  end

  test "mixin initializer when args exist" do
    object = BasicModel.new(hello: 'world')
    assert_equal 'world', object.hello
  end

  test "mixin initializer when args dont exist" do
    assert_raises(NoMethodError) { SimpleModel.new(hello: 'world') }
  end
end
