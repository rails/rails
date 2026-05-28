# frozen_string_literal: true

require "cases/helper"
require "models/reply"

module ActiveRecord
  class PredicateBuilderTest < ActiveRecord::TestCase
    class UnaccentedString < ActiveRecord::Type::String
      def query_transformable?
        true
      end

      def query_attribute(attribute)
        normalize(attribute)
      end

      def query_value(attribute, value, predicate_builder:)
        normalize(predicate_builder.build_bind_attribute(attribute.name, value))
      end

      private
        def normalize(node)
          Arel::Nodes::NamedFunction.new(
            "lower",
            [Arel::Nodes::NamedFunction.new("custom_immutable_unaccent", [node])]
          )
        end
    end

    class UuidToBinString < ActiveRecord::Type::String
      UUID_STRING = ActiveRecord::Type::String.new

      def query_transformable?
        true
      end

      def query_value(attribute, value, predicate_builder:)
        bind = Relation::QueryAttribute.new(attribute.name, value, UUID_STRING)
        Arel::Nodes::NamedFunction.new("UUID_TO_BIN", [bind])
      end
    end

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

    def test_attribute_type_can_transform_query_attribute_and_value
      topic = topic_model_with_title_type(UnaccentedString.new)
      sql = topic.where(title: "CAFE").to_sql

      assert_includes sql, "lower(custom_immutable_unaccent("
      assert_includes sql, ") = lower(custom_immutable_unaccent("
      assert_includes sql, "'CAFE'"
    end

    def test_attribute_type_can_transform_array_query_values
      topic = topic_model_with_title_type(UnaccentedString.new)
      sql = topic.where(title: ["CAFE", "BAR"]).to_sql

      assert_includes sql, "lower(custom_immutable_unaccent("
      assert_includes sql, " IN "
      assert_equal 3, sql.scan("lower(custom_immutable_unaccent(").length
    end

    def test_attribute_type_can_transform_range_query_values
      topic = topic_model_with_title_type(UnaccentedString.new)
      sql = topic.where(title: "A".."Z").to_sql

      assert_includes sql, " BETWEEN "
      assert_equal 3, sql.scan("lower(custom_immutable_unaccent(").length
    end

    def test_attribute_type_can_transform_only_query_value
      topic = topic_model_with_title_type(UuidToBinString.new)
      uuid = "6ccd780c-baba-1026-9564-5b8c656024db"
      sql = topic.where(title: uuid).to_sql

      assert_includes sql, "UUID_TO_BIN("
      assert_includes sql, uuid
      assert_no_match(/custom_immutable_unaccent/, sql)
    end

    def test_attribute_type_query_transform_keeps_nil_predicates_unwrapped
      topic = topic_model_with_title_type(UnaccentedString.new)
      sql = topic.where(title: nil).to_sql

      assert_includes sql, " IS NULL"
      assert_no_match(/custom_immutable_unaccent/, sql)
    end

    private
      def topic_model_with_title_type(type)
        Class.new(Topic) do
          self.table_name = "topics"
          attribute :title, type
        end
      end
  end
end
