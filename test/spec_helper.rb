require 'rubygems'
require 'minitest/autorun'
require 'fileutils'
require 'arel'

require 'support/fake_record'
Arel::Table.engine = Arel::Sql::Engine.new(FakeRecord::Base.new)

# HACK require 'support/shared/tree_manager_shared'

class Object
  def must_be_like other
    self.gsub(/\s+/, ' ').strip.must_equal other.gsub(/\s+/, ' ').strip
  end

  # TODO: remove
  def check truthiness
    raise "not truthy" unless truthiness
  end
end

