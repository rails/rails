# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module Coders
    class JSONTest < ActiveRecord::TestCase
      def test_returns_nil_if_empty_string_given
        coder = JSON.new
        assert_nil coder.load("")
      end

      def test_returns_nil_if_nil_given
        coder = JSON.new
        assert_nil coder.load(nil)
      end

      def test_coder_with_symbolize_names
        coder = JSON.new(symbolize_names: true)
        assert_equal({ foo: "bar" }, coder.load('{"foo":"bar"}'))
      end
    end
  end
end
