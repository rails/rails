require "cases/helper"
require 'models/topic'

module ActiveRecord
  class PredicateBuilderTest < ActiveRecord::TestCase
    def test_registering_new_handlers
      PredicateBuilder.register_handler(Regexp, proc do |column, value|
        Arel::Nodes::InfixOperation.new('~', column, Arel.sql(value.source))
      end)

      assert_match %r{["`]topics["`].["`]title["`] ~ rails}i, Topic.where(title: /rails/).to_sql
    end
  end
end
