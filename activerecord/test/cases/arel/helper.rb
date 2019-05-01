# frozen_string_literal: true

require "active_support"
require "minitest/autorun"
require "arel"

require_relative "support/fake_record"

class Object
  def must_be_like(other)
    gsub(/\s+/, " ").strip.must_equal other.gsub(/\s+/, " ").strip
  end
end

module Arel
  class Test < ActiveSupport::TestCase
    def setup
      super
      @arel_engine = Arel::Table.engine
      Arel::Table.engine = FakeRecord::Base.new
    end

    def teardown
      Arel::Table.engine = @arel_engine if defined? @arel_engine
      super
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
    include ActiveSupport::Testing::Assertions

    # test/unit backwards compatibility methods
    alias :assert_no_match :refute_match
    alias :assert_not_equal :refute_equal
    alias :assert_not_same :refute_same
  end
end
