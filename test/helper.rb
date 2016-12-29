require 'rubygems'
require 'minitest/autorun'
require 'fileutils'
require 'arel'

require 'support/fake_record'
Arel::Table.engine = FakeRecord::Base.new

class Object
  def must_be_like other
    gsub(/\s+/, ' ').strip.must_equal other.gsub(/\s+/, ' ').strip
  end
end

module Arel
  class Test < MiniTest::Test
    def assert_like expected, actual
      assert_equal expected.gsub(/\s+/, ' ').strip,
                   actual.gsub(/\s+/, ' ').strip
    end
  end
end
