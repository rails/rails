# frozen_string_literal: true

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

    def test_range_collapsing_with_begin_and_end_equality
      date = Date.new(2004, 04, 15)
      assert_no_match(/BETWEEN/i, Topic.where(last_read: date..date).to_sql)
    end
  end
end
