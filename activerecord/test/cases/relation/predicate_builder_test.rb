require "cases/helper"
require "models/topic"

module ActiveRecord
  class PredicateBuilderTest < ActiveRecord::TestCase
    def test_registering_new_handlers
      Topic.predicate_builder.register_handler(Regexp, proc do |column, value|
        Arel::Nodes::InfixOperation.new("~", column, Arel.sql(value.source))
      end)

      assert_match %r{["`]topics["`]\.["`]title["`] ~ rails}i, Topic.where(title: /rails/).to_sql
    ensure
      Topic.reset_column_information
    end
  end
end
