# frozen_string_literal: true

require "rubygems"
require "minitest/autorun"
require "arel"

require_relative "support/fake_record"

class Object
  def must_be_like(other)
    gsub(/\s+/, " ").strip.must_equal other.gsub(/\s+/, " ").strip
  end
end

module Arel
  class Test < Minitest::Test
    def setup
      super
      @arel_engine = Arel::Table.engine
      Arel::Table.engine = FakeRecord::Base.new
    end

    def teardown
      Arel::Table.engine = @arel_engine if defined? @arel_engine
      super
    end

    def assert_like(expected, actual)
      assert_equal expected.gsub(/\s+/, " ").strip,
                   actual.gsub(/\s+/, " ").strip
    end
  end

  class Spec < Minitest::Spec
    before do
      @arel_engine = Arel::Table.engine
      Arel::Table.engine = FakeRecord::Base.new
    end

    after do
      Arel::Table.engine = @arel_engine if defined? @arel_engine
    end
  end
end
