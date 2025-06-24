# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/object/with"

class WithTest < ActiveSupport::TestCase
  class Record
    def initialize
      @public_attr = :public
      @another_public_attr = :another_public
      @mixed_attr = :mixed
      @protected_attr = :protected
      @private_attr = :private
    end

    attr_accessor :public_attr, :another_public_attr

    attr_reader :mixed_attr

    protected
      attr_accessor :protected_attr

    private
      attr_accessor :private_attr
      attr_writer :mixed_attr
  end

  setup do
    @object = Record.new
  end

  test "sets and restore attributes around a block" do
    assert_equal :public, @object.public_attr
    assert_equal :another_public, @object.another_public_attr

    @object.with(public_attr: :changed, another_public_attr: :changed_too) do
      assert_equal :changed, @object.public_attr
      assert_equal :changed_too, @object.another_public_attr
    end

    assert_equal :public, @object.public_attr
    assert_equal :another_public, @object.another_public_attr
  end

  test "restore attribute if the block raised" do
    assert_equal :public, @object.public_attr
    assert_equal :another_public, @object.another_public_attr

    assert_raise RuntimeError do
      @object.with(public_attr: :changed, another_public_attr: :changed_too) do
        assert_equal :changed, @object.public_attr
        assert_equal :changed_too, @object.another_public_attr
        raise "Oops"
      end
    end

    assert_equal :public, @object.public_attr
    assert_equal :another_public, @object.another_public_attr
  end

  test "restore attributes if one of the setter raised" do
    assert_equal :public, @object.public_attr
    assert_equal :mixed, @object.mixed_attr

    assert_raise NoMethodError do
      @object.with(public_attr: :changed, mixed_attr: :changed_too) do
        assert false
      end
    end

    assert_equal :public, @object.public_attr
    assert_equal :mixed, @object.mixed_attr
  end

  test "only works with public attributes" do
    assert_raises NoMethodError do
      @object.with(private_attr: :changed) { }
    end

    assert_raises NoMethodError do
      @object.with(protected_attr: :changed) { }
    end

    assert_equal :mixed, @object.mixed_attr
    assert_raises NoMethodError do
      @object.with(mixed_attr: :changed) { }
    end
    assert_equal :mixed, @object.mixed_attr
  end

  test "yields the instance to the block" do
    assert_equal "1", @object.with(public_attr: "1", &:public_attr)
  end

  test "basic immediates don't respond to #with" do
    assert_not_respond_to nil, :with
    assert_not_respond_to true, :with
    assert_not_respond_to false, :with
    assert_not_respond_to 1, :with
    assert_not_respond_to 1.0, :with
    assert_not_respond_to :sym, :with
  end
end
