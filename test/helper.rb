require 'rubygems'
require 'minitest/autorun'
require 'fileutils'
require 'arel'

require 'support/fake_record'
Arel::Table.engine = Arel::Sql::Engine.new(FakeRecord::Base.new)

class Object
  def must_be_like other
    gsub(/\s+/, ' ').strip.must_equal other.gsub(/\s+/, ' ').strip
  end
end
