# frozen_string_literal: true

require "cases/helper"

class ModelWithAttributes
  include ActiveModel::AttributeMethods

  class << self
    define_method(:bar) do
      "original bar"
    end
  end

  def attributes
    { foo: "value of foo", baz: "value of baz" }
  end

private
  def attribute(name)
    attributes[name.to_sym]
  end
end

class ModelWithAttributes2
  include ActiveModel::AttributeMethods

  attr_accessor :attributes

  attribute_method_suffix "_test", "_kw"

private
  def attribute(name)
    attributes[name.to_s]
  end

  def attribute_test(name, attrs = {})
    attrs[name] = attribute(name)
  end

  def attribute_kw(name, kw: 1)
    attribute(name)
  end

  def private_method
    "<3 <3"
  end

protected
  def protected_method
    "O_o O_o"
  end
end

class ModelWithAttributesWithSpaces
  include ActiveModel::AttributeMethods

  def attributes
    { 'foo bar': "value of foo bar" }
  end

private
  def attribute(name)
    attributes[name.to_sym]
  end
end

class ModelWithWeirdNamesAttributes
  include ActiveModel::AttributeMethods

  class << self
    define_method(:'c?d') do
      "original c?d"
    end
  end

  def attributes
    { 'a?b': "value of a?b" }
  end

private
  def attribute(name)
    attributes[name.to_sym]
  end
end

class ModelWithRubyKeywordNamedAttributes
  include ActiveModel::AttributeMethods

  def attributes
    { begin: "value of begin", end: "value of end" }
  end

private
  def attribute(name)
    attributes[name.to_sym]
  end
end

class ModelWithoutAttributesMethod
  include ActiveModel::AttributeMethods
end

class AttributeMethodsTest < ActiveModel::TestCase
  test "method missing works correctly even if attributes method is not defined" do
    assert_raises(NoMethodError) { ModelWithoutAttributesMethod.new.foo }
  end

  test "unrelated classes should not share attribute method matchers" do
    assert_not_equal ModelWithAttributes.public_send(:attribute_method_patterns),
                     ModelWithAttributes2.public_send(:attribute_method_patterns)
  end

  test "#define_attribute_method generates attribute method" do
    ModelWithAttributes.define_attribute_method(:foo)

    assert_respond_to ModelWithAttributes.new, :foo
    assert_equal "value of foo", ModelWithAttributes.new.foo
  ensure
    ModelWithAttributes.undefine_attribute_methods
  end

  test "#define_attribute_methods defines alias attribute methods after undefining" do
    topic_class = Class.new do
      include ActiveModel::AttributeMethods
      define_attribute_methods :title
      alias_attribute :aliased_title_to_be_redefined, :title

      def attributes
        { title: "Active Model Topic" }
      end

      private
        def attribute(name)
          attributes[name.to_sym]
        end
    end

    topic = topic_class.new
    assert_equal("Active Model Topic", topic.aliased_title_to_be_redefined)
    topic_class.undefine_attribute_methods

    assert_not_respond_to topic, :aliased_title_to_be_redefined

    topic_class.define_attribute_methods :title

    assert_respond_to topic, :aliased_title_to_be_redefined
    assert_equal "Active Model Topic", topic.aliased_title_to_be_redefined
  end

  test "#define_attribute_method does not generate attribute method if already defined in attribute module" do
    klass = Class.new(ModelWithAttributes)
    klass.send(:generated_attribute_methods).module_eval do
      def foo
        "<3"
      end
    end
    klass.define_attribute_method(:foo)

    assert_equal "<3", klass.new.foo
  end

  test "#define_attribute_method generates a method that is already defined on the host" do
    klass = Class.new(ModelWithAttributes) do
      def foo
        super
      end
    end
    klass.define_attribute_method(:foo)

    assert_equal "value of foo", klass.new.foo
  end

  test "#define_attribute_method generates attribute method with invalid identifier characters" do
    ModelWithWeirdNamesAttributes.define_attribute_method(:'a?b')

    assert_respond_to ModelWithWeirdNamesAttributes.new, :'a?b'
    assert_equal "value of a?b", ModelWithWeirdNamesAttributes.new.public_send("a?b")
  ensure
    ModelWithWeirdNamesAttributes.undefine_attribute_methods
  end

  test "#define_attribute_methods works passing multiple arguments" do
    ModelWithAttributes.define_attribute_methods(:foo, :baz)

    assert_equal "value of foo", ModelWithAttributes.new.foo
    assert_equal "value of baz", ModelWithAttributes.new.baz
  ensure
    ModelWithAttributes.undefine_attribute_methods
  end

  test "#define_attribute_methods generates attribute methods" do
    ModelWithAttributes.define_attribute_methods(:foo)

    assert_respond_to ModelWithAttributes.new, :foo
    assert_equal "value of foo", ModelWithAttributes.new.foo
  ensure
    ModelWithAttributes.undefine_attribute_methods
  end

  test "#alias_attribute generates attribute_aliases lookup hash" do
    klass = Class.new(ModelWithAttributes) do
      define_attribute_methods :foo
      alias_attribute :bar, :foo
    end

    assert_equal({ "bar" => "foo" }, klass.attribute_aliases)
  end

  test "#define_attribute_methods generates attribute methods with spaces in their names" do
    ModelWithAttributesWithSpaces.define_attribute_methods(:'foo bar')

    assert_respond_to ModelWithAttributesWithSpaces.new, :'foo bar'
    assert_equal "value of foo bar", ModelWithAttributesWithSpaces.new.public_send(:'foo bar')
  ensure
    ModelWithAttributesWithSpaces.undefine_attribute_methods
  end

  test "#alias_attribute works with attributes with spaces in their names" do
    ModelWithAttributesWithSpaces.define_attribute_methods(:'foo bar')
    ModelWithAttributesWithSpaces.alias_attribute(:'foo_bar', :'foo bar')

    assert_equal "value of foo bar", ModelWithAttributesWithSpaces.new.foo_bar
  ensure
    ModelWithAttributesWithSpaces.undefine_attribute_methods
  end

  test "#alias_attribute works with attributes named as a ruby keyword" do
    ModelWithRubyKeywordNamedAttributes.define_attribute_methods([:begin, :end])
    ModelWithRubyKeywordNamedAttributes.alias_attribute(:from, :begin)
    ModelWithRubyKeywordNamedAttributes.alias_attribute(:to, :end)

    assert_equal "value of begin", ModelWithRubyKeywordNamedAttributes.new.from
    assert_equal "value of end", ModelWithRubyKeywordNamedAttributes.new.to
  ensure
    ModelWithRubyKeywordNamedAttributes.undefine_attribute_methods
  end

  test "#undefine_attribute_methods removes attribute methods" do
    ModelWithAttributes.define_attribute_methods(:foo)
    ModelWithAttributes.undefine_attribute_methods

    assert_not_respond_to ModelWithAttributes.new, :foo
    assert_raises(NoMethodError) { ModelWithAttributes.new.foo }
  end

  test "#undefine_attribute_methods undefines alias attribute methods" do
    topic_class = Class.new do
      include ActiveModel::AttributeMethods
      define_attribute_methods :title
      alias_attribute :subject_to_be_undefined, :title

      def attributes
        { title: "Active Model Topic" }
      end

      private
        def attribute(name)
          attributes[name.to_sym]
        end
    end

    assert_equal("Active Model Topic", topic_class.new.subject_to_be_undefined)
    topic_class.undefine_attribute_methods

    assert_raises(NoMethodError, match: /undefined method [`']subject_to_be_undefined'/) do
      topic_class.new.subject_to_be_undefined
    end
  end

  test "accessing a suffixed attribute" do
    m = ModelWithAttributes2.new
    m.attributes = { "foo" => "bar" }
    attrs = {}

    assert_equal "bar", m.foo
    assert_equal "bar", m.foo_kw(kw: 2)
    assert_equal "bar", m.foo_test(attrs)
    assert_equal "bar", attrs["foo"]
  end

  test "defined attribute doesn't expand positional hash argument" do
    ModelWithAttributes2.define_attribute_methods(:foo)

    m = ModelWithAttributes2.new
    m.attributes = { "foo" => "bar" }
    attrs = {}

    assert_equal "bar", m.foo
    assert_equal "bar", m.foo_kw(kw: 2)
    assert_equal "bar", m.foo_test(attrs)
    assert_equal "bar", attrs["foo"]
  ensure
    ModelWithAttributes2.undefine_attribute_methods
  end

  test "should not interfere with method_missing if the attr has a private/protected method" do
    m = ModelWithAttributes2.new
    m.attributes = { "private_method" => "<3", "protected_method" => "O_o" }

    # dispatches to the *method*, not the attribute
    assert_equal "<3 <3",   m.send(:private_method)
    assert_equal "O_o O_o", m.send(:protected_method)

    # sees that a method is already defined, so doesn't intervene
    assert_raises(NoMethodError) { m.private_method }
    assert_raises(NoMethodError) { m.protected_method }
  end

  class ClassWithProtected
    protected
      def protected_method
      end
  end

  test "should not interfere with respond_to? if the attribute has a private/protected method" do
    m = ModelWithAttributes2.new
    m.attributes = { "private_method" => "<3", "protected_method" => "O_o" }

    assert_not_respond_to m, :private_method
    assert m.respond_to?(:private_method, true)

    c = ClassWithProtected.new

    # This is messed up, but it's how Ruby works at the moment. Apparently it will be changed
    # in the future.
    assert_equal c.respond_to?(:protected_method), m.respond_to?(:protected_method)
    assert m.respond_to?(:protected_method, true)
  end

  test "should use attribute_missing to dispatch a missing attribute" do
    m = ModelWithAttributes2.new
    m.attributes = { "foo" => "bar" }

    def m.attribute_missing(match, *args, &block)
      match
    end

    match = m.foo_test

    assert_equal "foo",            match.attr_name
    assert_equal "attribute_test", match.proxy_target
  end

  module NameClash
    class Model1
      include ActiveModel::AttributeMethods
      attribute_method_suffix "_changed?"
      define_attribute_methods :x
      attr_accessor :x

      private
        def attribute_changed?(name)
          :model_1
        end
    end

    class Model2
      include ActiveModel::AttributeMethods
      attribute_method_suffix "?"
      define_attribute_methods :x_changed
      attr_accessor :x_changed

      private
        def attribute?(name)
          :model_2
        end
    end
  end

  test "name clashes are handled" do
    assert_equal :model_1, NameClash::Model1.new.x_changed?
    assert_equal :model_2, NameClash::Model2.new.x_changed?
  end

  test "alias attribute respects user defined method" do
    model = Class.new do
      include ActiveModel::AttributeMethods

      attr_accessor :name
      define_attribute_methods :name

      alias_attribute :nickname, :name

      def initialize(name)
        @name = name
      end
    end

    instance = model.new("George")
    assert_equal "George", instance.name
    assert_equal "George", instance.nickname
  end

  test "alias attribute respects user defined method in parent classes" do
    model = Class.new do
      include ActiveModel::AttributeMethods

      attr_accessor :name
      define_attribute_methods :name

      def initialize(name)
        @name = name
      end
    end

    subclass = Class.new(model) do
      alias_attribute :nickname, :name
    end

    instance = subclass.new("George")
    assert_equal "George", instance.name
    assert_equal "George", instance.nickname
  end
end
