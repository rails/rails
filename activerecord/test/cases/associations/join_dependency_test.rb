require "cases/helper"
require 'models/edge'

class JoinDependencyTest < ActiveRecord::TestCase
  def test_column_names_with_alias_handles_nil_primary_key
    assert_equal Edge.column_names, ActiveRecord::Associations::JoinDependency::JoinBase.new(Edge).column_names_with_alias.map(&:first)
  end
end