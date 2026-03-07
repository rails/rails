# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/object/blank"

class BlankTest < ActiveSupport::TestCase
  class EmptyTrue
    def empty?
      0
    end
  end

  class EmptyFalse
    def empty?
      nil
    end
  end

  BLANK = [ EmptyTrue.new, nil, false, "", "   ", "  \n\t  \r ", "　", "\u00a0", [], {} ]
  NOT   = [ EmptyFalse.new, Object.new, true, 0, 1, "a", [nil], { nil => 0 }, Time.now ]

  def test_blank
    BLANK.each { |v| assert_equal true, v.blank?,  "#{v.inspect} should be blank" }
    NOT.each   { |v| assert_equal false, v.blank?, "#{v.inspect} should not be blank" }
  end

  def test_blank_with_bundled_string_encodings
    Encoding.list.reject(&:dummy?).each do |encoding|
      assert_predicate " ".encode(encoding), :blank?
      assert_not_predicate "a".encode(encoding), :blank?
    end
  end

  def test_present
    BLANK.each { |v| assert_equal false, v.present?, "#{v.inspect} should not be present" }
    NOT.each   { |v| assert_equal true, v.present?,  "#{v.inspect} should be present" }
  end

  def test_presence
    BLANK.each { |v| assert_nil v.presence, "#{v.inspect}.presence should return nil" }
    NOT.each   { |v| assert_equal v,   v.presence, "#{v.inspect}.presence should return self" }
  end

  def test_delegator_presence_returns_self_without_touching_wrapped_object
    require "delegate"

    klass = Class.new(Delegator) do
      attr_reader :inner_obj

      def initialize
        __setobj__(Object.new)
      end

      def __setobj__(obj)
        @inner_obj = obj
      end

      def __getobj__
        @inner_obj
      end

      def deliver_now
        :delivered
      end
    end

    delegator = klass.new
    assert_same delegator, delegator.presence
    assert_equal :delivered, delegator.presence.deliver_now
  end
end
