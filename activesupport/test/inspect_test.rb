# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/inspect"

class InspectTest < ActiveSupport::TestCase
  class ComplexObject
    def initialize(id, username, name, interests, password_digest)
      @id = id
      @username = username
      @name = name
      @interests = interests
      @password_digest = password_digest
    end

    include ActiveSupport::Inspect(:@name, :interest_count, :longer_attribute) { [@id, @username.inspect] }

    def interest_count
      @interests.size
    end

    def longer_attribute
      "attribute value"
    end
  end

  def setup
    @object = ComplexObject.new(17, "james", "James", %w(ruby rails), "password")
  end

  test "#inspect" do
    assert_equal "#<InspectTest::ComplexObject 17 \"james\" @name=\"James\" interest_count=2 longer_attribute=\"attribute value\">", @object.inspect
  end

  test "#to_s" do
    assert_equal "#<InspectTest::ComplexObject 17 \"james\">", @object.to_s
  end

  test "#pretty_print" do
    output = +""
    PP.pp(@object, output, 20)
    assert_equal <<~OUT, output
    #<InspectTest::ComplexObject
     17 "james"
     @name="James"
     interest_count=2
     longer_attribute=
      "attribute value">
    OUT
  end

  class InheritanceParent
    def inspect
      "custom inspect"
    end

    def to_s
      "custom to_s"
    end
  end

  class ChildWithInspect < InheritanceParent
    include ActiveSupport::Inspect()
  end

  test "overrides an inherited #inspect" do
    assert_equal "custom inspect", InheritanceParent.new.inspect
    assert_equal "#<InspectTest::ChildWithInspect>", ChildWithInspect.new.inspect
  end

  test "avoids overriding an existing inherited #to_s" do
    assert_equal "custom to_s", InheritanceParent.new.to_s
    assert_equal "custom to_s", ChildWithInspect.new.to_s
  end

  class EmptyInspect
    include ActiveSupport::Inspect()
  end

  OBJECT_ADDRESS = /0x\h+/
  ANONYMOUS_CLASS = /#<Class:#{OBJECT_ADDRESS}>/

  test "omits object id by default" do
    object = EmptyInspect.new
    assert_match(/\#<InspectTest::EmptyInspect>/, object.inspect)
  end

  test "omits object id when disabled" do
    very_empty = Class.new do
      include ActiveSupport::Inspect(id: false)
    end.new

    assert_match(/^\#<#{ANONYMOUS_CLASS}>$/, very_empty.inspect)
  end

  class IdInspect
    include ActiveSupport::Inspect(id: true) { "some label" }
  end

  test "includes object id when explicitly enabled" do
    object = IdInspect.new
    assert_match(/\#<InspectTest::IdInspect:#{address_of(object)} some label>/, object.inspect)
  end

  test "omits object id when a label is supplied" do
    labelled_object = Class.new do
      include ActiveSupport::Inspect(label: :my_label)

      def my_label
        "my label"
      end
    end.new

    # Label string via symbol is automatically inspected
    assert_match(/^\#<#{ANONYMOUS_CLASS} "my label">$/, labelled_object.inspect)
  end

  test "separates multiple label elements" do
    dual_labelled_object = Class.new do
      include ActiveSupport::Inspect() { [my_label, my_other_label] }

      def my_label
        "(my label)"
      end

      def my_other_label
        :my_other_label
      end
    end.new

    # String label components from a block are inserted as-is; other types are inspected
    assert_match(/^\#<#{ANONYMOUS_CLASS} \(my label\) :my_other_label>$/, dual_labelled_object.inspect)
  end

  test "includes specified attributes in order" do
    attributed_object = Class.new do
      include ActiveSupport::Inspect(:@name, :@id)

      def initialize(name, id)
        @name = name
        @id = id
      end
    end.new("james", 17)

    assert_match(/\#<#{ANONYMOUS_CLASS} @name="james" @id=17>/, attributed_object.inspect)
  end

  test "a hash inside attributes gets expanded" do
    dynamically_attributed_object = Class.new do
      include ActiveSupport::Inspect(:basic_attribute, { "dynamic" => :callable, "expr" => "2 > 1", :hash => { structure: ["nestable"] } }, :another_attribute) { "static label" }

      def callable
        "called"
      end

      def basic_attribute
        "basic"
      end

      def another_attribute
        "another"
      end
    end.new

    assert_match(/\#<#{ANONYMOUS_CLASS} static label basic_attribute="basic" dynamic=\"called\" expr=true hash=\{:structure=>\["nestable"\]\} another_attribute="another">/, dynamically_attributed_object.inspect)
  end

  class CyclicInspect
    include ActiveSupport::Inspect(:@attribute, :static, id: true) { ["simple", :symbol, 123, @label] }

    attr_accessor :label, :attribute

    def static
      "value"
    end
  end

  test "handles cyclic references in label" do
    object = CyclicInspect.new
    object.label = object
    object.attribute = object

    nested_reference = /\#<InspectTest::CyclicInspect:#{address_of(object)} simple :symbol 123 ... ...>/
    assert_match(/^\#<InspectTest::CyclicInspect:#{address_of(object)} simple :symbol 123 #{nested_reference} @attribute=#{nested_reference} static="value">$/, object.inspect)
  end

  test "handles cyclic references in attributes" do
    object = CyclicInspect.new
    object.label = "safe-label"
    object.attribute = object

    nested_reference = /\#<InspectTest::CyclicInspect:#{address_of(object)} simple :symbol 123 safe-label ...>/
    assert_match(/^\#<InspectTest::CyclicInspect:#{address_of(object)} simple :symbol 123 safe-label @attribute=#{nested_reference} static="value">$/, object.inspect)
  end

  private
    def address_of(object)
      ::Kernel.instance_method(:to_s).bind_call(object).match(/#{OBJECT_ADDRESS}(?=>$)/)
    end
end
