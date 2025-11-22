# frozen_string_literal: true

require "cases/helper"
require "models/reply"

module ActiveRecord
  class PredicateBuilderTest < ActiveRecord::TestCase
    def setup
      Topic.predicate_builder.register_handler(Regexp, proc do |column, value|
        Arel::Nodes::InfixOperation.new("~", column, Arel::Nodes.build_quoted(value.source))
      end)
    end

    def teardown
      Topic.class_eval { @predicate_builder = nil }
    end

    def test_registering_new_handlers
      assert_match %r{#{Regexp.escape(quote_table_name("topics.title"))} ~ 'rails'}i, Topic.where(title: /rails/).to_sql
    end

    def test_registering_new_handlers_for_association
      assert_match %r{#{Regexp.escape(quote_table_name("topics.title"))} ~ 'rails'}i, Reply.joins(:topic).where(topics: { title: /rails/ }).to_sql
    end

    def test_registering_new_handlers_for_joins
      Reply.belongs_to :regexp_topic, -> { where(title: /rails/) }, class_name: "Topic", foreign_key: "parent_id"

      assert_match %r{#{Regexp.escape(quote_table_name("regexp_topic.title"))} ~ 'rails'}i, Reply.joins(:regexp_topic).references(Arel.sql("regexp_topic")).to_sql
    end

    def test_references_with_schema
      assert_equal %w{schema.table}, ActiveRecord::PredicateBuilder.references(%w{schema.table.column})
    end

    def test_build_from_hash_with_schema
      assert_match %r{schema.+table.+column}i, Topic.predicate_builder.build_from_hash("schema.table.column" => "value").first.to_sql
    end

    def test_does_not_mutate
      defaults = { topics: { title: "rails" }, "topics.approved" => true }
      Topic.where(defaults).to_sql
      assert_equal({ topics: { title: "rails" }, "topics.approved" => true }, defaults)
    end
  end
end
