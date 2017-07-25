# frozen_string_literal: true

require "cases/helper"
require "models/topic"

module ActiveRecord
  class PredicateBuilderTest < ActiveRecord::TestCase
    def setup
      Topic.predicate_builder.register_handler(Regexp, proc do |column, value|
        Arel::Nodes::InfixOperation.new("~", column, Arel::Nodes.build_quoted(value.source))
      end)
    end

    def teardown
      Topic.reset_column_information
    end

    def test_registering_new_handlers
      assert_match %r{["`]topics["`]\.["`]title["`] ~ 'rails'}i, Topic.where(title: /rails/).to_sql
    end

    def test_array_of_new_handlers_values
      assert_match %r{["`]topics["`]\.["`]title["`] ~ 'ruby' OR ["`]topics["`]\.["`]title["`] ~ 'rails'}i, Topic.where(title: [/ruby/, /rails/]).to_sql
    end
  end
end
