# frozen_string_literal: true

require "active_support"
require "arel"

require_relative "support/fake_record"

module Arel
  class Test < ActiveRecord::TestCase
    setup do
      @arel_engine = Arel::Table.engine
      Arel::Table.engine = FakeRecord::Base.new
    end

    teardown do
      Arel::Table.engine = @arel_engine if defined? @arel_engine
    end

    private
      def assert_like(expected, actual)
        assert_equal normalize_like_string(expected), normalize_like_string(actual)
      end

      def normalize_like_string(value)
        value.gsub(/\s+/, " ").strip
      end
  end
end
