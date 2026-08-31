# frozen_string_literal: true

require "cases/helper"
require "models/reply"
require "active_support/testing/ractors_assertions"
require "active_support/core_ext/object/with"

module ActiveRecord
  class PredicateBuilderTest < ActiveRecord::TestCase
    include ActiveSupport::Testing::RactorsAssertions
    class UnaccentedString < ActiveRecord::Type::String
      include ActiveRecord::Type::QueryPredicates

      def comparison_expression(expression)
        Arel::Nodes::NamedFunction.new(
          "lower",
          [Arel::Nodes::NamedFunction.new("custom_immutable_unaccent", [expression])]
        )
      end
    end

    class LowerString < ActiveRecord::Type::String
      include ActiveRecord::Type::QueryPredicates

      def comparison_expression(expression)
        Arel::Nodes::NamedFunction.new("lower", [expression])
      end
    end

    class UpperString < ActiveRecord::Type::String
      include ActiveRecord::Type::QueryPredicates

      def comparison_expression(expression)
        Arel::Nodes::NamedFunction.new("upper", [expression])
      end
    end

    class TypeCastingAttribute < Arel::Attributes::Attribute
      attr_reader :custom_type

      def initialize(relation, name, custom_type)
        super(relation, name)
        @custom_type = custom_type
      end

      def type_caster
        custom_type
      end

      def type_cast_for_database(value)
        ["custom", value]
      end
    end

    class TruncatedDateTime < ActiveRecord::Type::DateTime
      include ActiveRecord::Type::QueryPredicates

      def comparison_expression(expression)
        Arel::Nodes::NamedFunction.new("date", [expression])
      end
    end

    class FlooredBoundedInteger < ActiveRecord::Type::Integer
      include ActiveRecord::Type::QueryPredicates

      def comparison_expression(expression)
        Arel::Nodes::NamedFunction.new("floor", [expression])
      end
    end

    class FlooredFloat < ActiveRecord::Type::Float
      include ActiveRecord::Type::QueryPredicates

      def comparison_expression(expression)
        Arel::Nodes::NamedFunction.new("floor", [expression])
      end
    end

    class InvertedInteger < ActiveRecord::Type::Integer
      include ActiveRecord::Type::QueryPredicates

      def comparison_expression(expression)
        Arel::Nodes::Grouping.new(Arel::Nodes::Subtraction.new(0, expression))
      end
    end

    class InnerExpressionString < ActiveRecord::Type::String
      include ActiveRecord::Type::QueryPredicates

      def comparison_expression(expression)
        Arel::Nodes::NamedFunction.new("inner_comparison", [expression])
      end
    end

    class OuterExpressionDecorator < ActiveSupport::Delegation::DelegateClass(ActiveModel::Type::Value)
      include ActiveRecord::Type::QueryPredicates::Decorator

      def subtype
        __getobj__
      end

      def comparison_expression(expression)
        Arel::Nodes::NamedFunction.new("outer_comparison", [super])
      end
    end

    OpaqueDecorator = ActiveSupport::Delegation::DelegateClass(ActiveModel::Type::Value)

    class TrackingString < ActiveRecord::Type::String
      include ActiveRecord::Type::QueryPredicates

      attr_reader :expressions

      def initialize
        @expressions = []
        super
      end

      def comparison_expression(expression)
        expressions << expression
        expression
      end
    end

    class MutableSerializedType < ActiveRecord::Type::Value
      include ActiveRecord::Type::QueryPredicates

      attr_reader :serializations

      def initialize
        @serializations = 0
        super
      end

      def serialize(value)
        @serializations += 1
        value[:value]
      end

      def serialized?
        true
      end
    end

    module PrefixCoder
      def self.dump(value)
        "coded:#{value}"
      end

      def self.load(value)
        value&.delete_prefix("coded:")
      end
    end

    class UpperNamedAuthor < ActiveRecord::Base
      self.table_name = "authors"

      attribute :name, UpperString.new
    end

    class MatchableAuthor < ActiveRecord::Base
      self.table_name = "authors"

      attribute :name, LowerString.new

      has_many :matching_authors, class_name: "MatchableAuthor", primary_key: :name, foreign_key: :name
      has_many :upper_matching_authors, class_name: "UpperNamedAuthor", primary_key: :name, foreign_key: :name
      has_many :matches_of_matches, through: :matching_authors, source: :matching_authors
    end

    class RegexpPredicateBuilder < PredicateBuilder
      def register_handlers
        super

        register_handler(Regexp, ActiveSupport::Ractors.shareable_proc do |column, value|
          Arel::Nodes::InfixOperation.new("~", column, Arel::Nodes.build_quoted(value.source))
        end)
      end
    end

    class RawRegexpPredicateBuilder < PredicateBuilder
      def register_handlers
        super

        register_handler(Regexp, ActiveSupport::Ractors.shareable_proc do |column, value|
          raw_column = nil
          column.fetch_attribute { |attribute| raw_column = attribute }
          Arel::Nodes::InfixOperation.new("~", raw_column, Arel::Nodes.build_quoted(value.source))
        end)
      end
    end

    def setup
      builder = RegexpPredicateBuilder.new(TableMetadata.new(Topic, Topic.arel_table))
      Topic.class_eval { @predicate_builder = builder }
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

    def test_is_ractor_shareable
      assert_ractor_shareable Topic.predicate_builder
    end

    def test_is_eagerly_built_and_reachable_from_a_ractor
      model = Class.new(ActiveRecord::Base) do
        def self.name
          "PredicateBuilderEagerModel"
        end

        self.table_name = "topics"
      end

      builder = on_ractor(model) { |m| m.instance_variable_get(:@predicate_builder) }

      assert_same model.predicate_builder, builder
    end

    def test_attribute_type_can_define_a_comparison_expression
      topic = topic_model_with_title_type(UnaccentedString.new)
      sql = topic.where(title: "CAFE").to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE #{normalized_title} = #{normalized_value("CAFE")}"

      assert_equal expected_sql, sql
    end

    def test_comparison_expression_applies_to_sql_literal_values_without_serializing_them
      topic = Class.new(ActiveRecord::Base) do
        self.table_name = "topics"
        attribute :replies_count, FlooredBoundedInteger.new
      end
      sql = topic.where(replies_count: Arel.sql(quote_table_name("topics.parent_id"))).to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE floor(#{quote_table_name("topics.replies_count")}) = floor(#{quote_table_name("topics.parent_id")})"

      assert_equal expected_sql, sql
    end

    def test_comparison_attribute_preserves_custom_type_casting
      type = LowerString.new
      attribute = TypeCastingAttribute.new(Topic.arel_table, "title", type)
      predicate = Topic.predicate_builder.build(attribute, "CAFE")

      assert_same type, predicate.left.type_caster
      assert_equal ["custom", "CAFE"], predicate.left.type_cast_for_database("CAFE")
      assert_equal "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE lower(#{quote_table_name("topics.title")}) = lower('CAFE')", Topic.where(predicate).to_sql
    end

    def test_scalar_query_predicate_expressions_are_built_eagerly
      type = TrackingString.new
      topic = topic_model_with_title_type(type)
      relation = topic.where(title: "CAFE")

      assert_equal 2, type.expressions.size
      relation.to_sql
      assert_equal 2, type.expressions.size
    end

    def test_query_predicate_expression_decorators_stack
      type = OuterExpressionDecorator.new(InnerExpressionString.new)
      topic = topic_model_with_title_type(type)
      sql = topic.where(title: "VALUE").to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE outer_comparison(inner_comparison(#{quote_table_name("topics.title")})) = " \
        "outer_comparison(inner_comparison('VALUE'))"

      assert_equal expected_sql, sql
    end

    def test_opaque_type_decorators_stop_query_predicate_composition
      type = OpaqueDecorator.new(LowerString.new)
      topic = topic_model_with_title_type(type)
      sql = topic.where(title: "value").to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE #{quote_table_name("topics.title")} = 'value'"

      assert_equal expected_sql, sql
    end

    def test_comparison_expression_composes_with_custom_predicate_handlers
      topic = topic_model_with_title_type(UnaccentedString.new)
      builder = RegexpPredicateBuilder.new(TableMetadata.new(topic, topic.arel_table))
      topic.class_eval { @predicate_builder = builder }
      sql = topic.where(title: /cafe/).to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE #{normalized_title} ~ 'cafe'"

      assert_equal expected_sql, sql
    end

    def test_custom_predicate_handlers_can_access_the_raw_attribute_and_type
      topic = topic_model_with_title_type(UnaccentedString.new)
      builder = RawRegexpPredicateBuilder.new(TableMetadata.new(topic, topic.arel_table))
      topic.class_eval { @predicate_builder = builder }
      attribute = builder.predicate_attribute(topic.arel_table[:title])
      sql = topic.where(title: /cafe/).to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE #{quote_table_name("topics.title")} ~ 'cafe'"

      assert_equal expected_sql, sql
      assert_instance_of UnaccentedString, attribute.type_caster
    end

    def test_attribute_type_comparison_expression_applies_to_array_values
      topic = topic_model_with_title_type(UnaccentedString.new)
      relation = topic.where(title: ["CAFE", "BAR"])
      values = relation.where_values_hash

      assert_instance_of Arel::Nodes::HomogeneousIn, relation.where_clause.ast
      sql = relation.to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE #{normalized_title} IN (#{normalized_value("CAFE")}, #{normalized_value("BAR")})"

      assert_equal expected_sql, sql
      assert_equal values, relation.where_values_hash
    end

    def test_attribute_type_comparison_expression_executes_array_predicates
      topic = topic_model_with_title_type(LowerString.new)
      records = [topic.create!(title: "Array One"), topic.create!(title: "Array Two")]
      topic.create!(title: "Other")

      assert_equal records, topic.where(title: ["ARRAY ONE", "ARRAY TWO"]).order(:id).to_a
    end

    def test_attribute_type_comparison_expression_applies_to_range_bounds
      topic = topic_model_with_title_type(UnaccentedString.new)
      sql = topic.where(title: "A".."Z").to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE #{normalized_title} BETWEEN #{normalized_value("A")} AND #{normalized_value("Z")}"

      assert_equal expected_sql, sql
    end

    def test_attribute_type_comparison_expression_applies_to_open_range_bounds
      topic = topic_model_with_title_type(UnaccentedString.new)
      sql = topic.where(title: .."M").to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE #{normalized_title} <= #{normalized_value("M")}"

      assert_equal expected_sql, sql
    end

    def test_attribute_type_comparison_expression_applies_to_nil_in_arrays
      topic = topic_model_with_title_type(UnaccentedString.new)
      sql = topic.where(title: ["CAFE", nil]).to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE (#{normalized_title} = #{normalized_value("CAFE")} OR #{normalized_title} IS NULL)"

      assert_equal expected_sql, sql
    end

    def test_attribute_type_comparison_expression_applies_to_explicit_operators
      topic = topic_model_with_title_type(UnaccentedString.new)
      predicate = topic.predicate_builder[:title, "M", :gt]
      sql = topic.where(predicate).to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE #{normalized_title} > #{normalized_value("M")}"

      assert_equal expected_sql, sql
    end

    def test_attribute_type_comparison_expression_applies_to_nil
      topic = topic_model_with_title_type(UnaccentedString.new)
      sql = topic.where(title: nil).to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE #{normalized_title} IS NULL"

      assert_equal expected_sql, sql
    end

    def test_attribute_type_comparison_expression_applies_to_where_not
      topic = topic_model_with_title_type(UnaccentedString.new)
      sql = topic.where.not(title: "CAFE").to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE #{normalized_title} != #{normalized_value("CAFE")}"

      assert_equal expected_sql, sql
    end

    def test_comparison_expression_preserves_unboundable_query_values
      topic = Class.new(ActiveRecord::Base) do
        self.table_name = "topics"
        attribute :replies_count, FlooredBoundedInteger.new
      end

      assert_equal "SELECT #{quoted_topics}.* FROM #{quoted_topics} WHERE 1=0", topic.where(replies_count: 2**100).to_sql
    end

    def test_comparison_expression_preserves_infinite_range_bounds
      topic = Class.new(ActiveRecord::Base) do
        self.table_name = "topics"
        attribute :replies_count, FlooredFloat.new
      end
      sql = topic.where(replies_count: 1.0..Float::INFINITY).to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE floor(#{quote_table_name("topics.replies_count")}) >= floor(1.0)"

      assert_equal expected_sql, sql
    end

    def test_comparison_expression_preserves_statement_cache_binds
      topic = topic_model_with_title_type(LowerString.new)
      record = topic.create!(title: "Mixed Case")

      assert_equal record, topic.find_by(title: "mixed case")
      assert_equal record, topic.find_by(title: "MIXED CASE")
    end

    def test_comparison_expression_preserves_serialized_values
      type = MutableSerializedType.new
      topic = topic_model_with_title_type(type)
      value = { value: "original" }
      relation = topic.where(title: value)
      value[:value] = "changed"

      assert_match(/= 'original'/, relation.to_sql)
      assert_equal 1, type.serializations
    end

    def test_comparison_attribute_preserves_where_clause_introspection
      topic = topic_model_with_title_type(UnaccentedString.new)
      relation = topic.where(title: "CAFE")

      assert_equal({ "title" => "CAFE" }, relation.where_values_hash)
      assert_no_match(/WHERE/, relation.unscope(where: :title).to_sql)
      assert_no_match(/WHERE/, relation.unscope(where: topic.arel_table[:title]).to_sql)
    end

    def test_comparison_attribute_preserves_where_clause_introspection_for_array_predicates
      topic = topic_model_with_title_type(UnaccentedString.new)
      relation = topic.where(title: ["CAFE", "BAR"])

      assert_equal({ "title" => ["CAFE", "BAR"] }, relation.where_values_hash)
      assert_no_match(/WHERE/, relation.unscope(where: :title).to_sql)
      assert_no_match(/WHERE/, relation.unscope(where: topic.arel_table[:title]).to_sql)
    end

    def test_comparison_attribute_preserves_where_clause_merge
      topic = topic_model_with_title_type(UnaccentedString.new)
      relation = topic.where.not(title: "CAFE").merge(topic.where.not(title: "BAR"))
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE #{normalized_title} != #{normalized_value("BAR")}"

      assert_equal expected_sql, relation.to_sql
    end

    def test_comparison_attribute_preserves_scope_for_create
      topic = topic_model_with_title_type(LowerString.new)
      record = topic.where(title: "Mixed Case").first_or_create!

      assert_equal "Mixed Case", record.title
      assert_equal record, topic.find_by(title: "MIXED CASE")
    end

    def test_query_predicates_compose_with_time_zone_conversion
      topic = Class.new(ActiveRecord::Base) do
        self.table_name = "topics"
        self.time_zone_aware_attributes = true
        attribute :written_on, TruncatedDateTime.new
      end
      type = topic.type_for_attribute("written_on")
      sql = topic.where(written_on: Time.utc(2024, 1, 2, 3, 4, 5)).to_sql

      assert ActiveRecord::Type::QueryPredicates.type?(type)
      assert_match(/date\(.+written_on.+\) = date\(/, sql)
    end

    def test_query_predicates_compose_with_optimistic_locking
      topic = Class.new(ActiveRecord::Base) do
        self.table_name = "topics"
        self.locking_column = :replies_count
        attribute :replies_count, FlooredBoundedInteger.new
      end
      type = topic.type_for_attribute("replies_count")
      sql = topic.where(replies_count: 1).to_sql

      assert ActiveRecord::Type::QueryPredicates.type?(type)
      assert_match(/floor\(.+replies_count.+\) = floor\(/, sql)
    end

    def test_query_predicates_compose_with_type_decorators
      topic = Class.new(ActiveRecord::Base) do
        self.table_name = "topics"
        attribute :title, LowerString.new
        normalizes :title, with: ->(title) { title.strip }
      end
      sql = topic.where(title: " PADDED ").to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE lower(#{quote_table_name("topics.title")}) = lower('PADDED')"

      assert_equal expected_sql, sql
    end

    def test_query_predicates_compose_with_enum_types
      topic = Class.new(ActiveRecord::Base) do
        self.table_name = "topics"
        attribute :title, LowerString.new
        enum :title, { draft: "PUBLISHED" }
      end
      sql = topic.where(title: :draft).to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE lower(#{quote_table_name("topics.title")}) = lower('PUBLISHED')"

      assert_equal expected_sql, sql
    end

    def test_query_predicates_compose_with_serialized_types
      type = ActiveRecord::Type::Serialized.new(LowerString.new, PrefixCoder)
      topic = topic_model_with_title_type(type)
      sql = topic.where(title: "VALUE").to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE lower(#{quote_table_name("topics.title")}) = lower('coded:VALUE')"

      assert_equal expected_sql, sql
    end

    def test_query_predicates_compose_with_serialized_types_in_arrays
      type = ActiveRecord::Type::Serialized.new(LowerString.new, PrefixCoder)
      topic = topic_model_with_title_type(type)
      sql = topic.where(title: ["ONE", "TWO"]).to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE lower(#{quote_table_name("topics.title")}) IN (lower('coded:ONE'), lower('coded:TWO'))"

      assert_equal expected_sql, sql
    end

    def test_relation_query_values_are_comparison_expressions
      topic = topic_model_with_title_type(UnaccentedString.new)
      query = topic.select(:title)
      query_sql = query.to_sql
      sql = topic.where(title: query).to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE #{normalized_title} IN (SELECT #{normalized_title} FROM #{quoted_topics})"

      assert_equal expected_sql, sql
      assert_equal query_sql, query.to_sql
    end

    def test_relation_query_values_preserve_projection_aliases
      topic = topic_model_with_title_type(UnaccentedString.new)
      sql = topic.where(title: topic.select(title: :candidate_title)).to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE #{normalized_title} IN (SELECT #{normalized_title} AS #{ActiveRecord::Base.lease_connection.quote_column_name("candidate_title")} FROM #{quoted_topics})"

      assert_equal expected_sql, sql
    end

    def test_relation_query_values_transform_sql_literal_projections
      topic = topic_model_with_title_type(UnaccentedString.new)
      projection = quote_table_name("topics.title")
      sql = topic.where(title: topic.select(projection)).to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE #{normalized_title} IN (SELECT #{normalized_title} FROM #{quoted_topics})"

      assert_equal expected_sql, sql
    end

    def test_association_join_constraints_use_query_predicate_expressions
      sql = MatchableAuthor.joins(:matching_authors).to_sql
      join_name = Regexp.escape(quote_table_name("matching_authors_authors.name"))
      owner_name = Regexp.escape(quote_table_name("authors.name"))

      assert_match %r{ON lower\(#{join_name}\) = lower\(#{owner_name}\)}, sql
    end

    def test_association_join_constraints_apply_each_columns_own_type
      sql = MatchableAuthor.joins(:upper_matching_authors).to_sql
      join_name = Regexp.escape(quote_table_name("upper_matching_authors_authors.name"))
      owner_name = Regexp.escape(quote_table_name("authors.name"))

      assert_match %r{ON upper\(#{join_name}\) = lower\(#{owner_name}\)}, sql
    end

    def test_association_join_constraints_execute_query_predicate_expressions
      MatchableAuthor.create!(name: "CAFE")
      MatchableAuthor.create!(name: "cafe")

      assert_equal 4, MatchableAuthor.where(name: "cafe").joins(:matching_authors).count
    end

    def test_through_association_scopes_use_query_predicate_expressions
      author = MatchableAuthor.create!(name: "Through Case")
      sql = author.matches_of_matches.to_sql
      middle_name = Regexp.escape(quote_table_name("matching_authors_matches_of_matches.name"))
      owner_name = Regexp.escape(quote_table_name("authors.name"))

      assert_match %r{ON lower\(#{owner_name}\) = lower\(#{middle_name}\)}, sql
      assert_match %r{WHERE lower\(#{middle_name}\) = lower\('Through Case'\)}, sql
    end

    def test_through_association_scopes_execute_query_predicate_expressions
      author = MatchableAuthor.create!(name: "Through Case")
      MatchableAuthor.create!(name: "THROUGH CASE")

      assert_equal 4, author.matches_of_matches.count
    end

    def test_through_association_scopes_preserve_aliased_table_references
      author = MatchableAuthor.create!(name: "Through Case")
      relation = author.matches_of_matches

      assert_equal [Arel.sql("matching_authors_matches_of_matches", retryable: true)], relation.references_values
    end

    def test_order_uses_query_predicate_expressions
      topic = topic_model_with_title_type(UnaccentedString.new)
      sql = topic.order(:title).to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "ORDER BY #{normalized_title} ASC"

      assert_equal expected_sql, sql
    end

    def test_order_directions_use_query_predicate_expressions
      topic = topic_model_with_title_type(UnaccentedString.new)
      sql = topic.order(title: :desc).to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "ORDER BY #{normalized_title} DESC"

      assert_equal expected_sql, sql
      assert_equal expected_sql, topic.order(:title).reverse_order.to_sql
    end

    def test_order_with_explicit_sql_uses_stored_attributes
      topic = topic_model_with_title_type(UnaccentedString.new)
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} ORDER BY title"

      assert_equal expected_sql, topic.order("title").to_sql
      assert_equal "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "ORDER BY #{quote_table_name("topics.title")}", topic.order(topic.arel_table[:title]).to_sql
    end

    def test_order_executes_query_predicate_expressions
      topic = Class.new(ActiveRecord::Base) do
        self.table_name = "topics"
        attribute :replies_count, InvertedInteger.new
      end
      topic.create!(title: "Inverted Order", replies_count: 1)
      topic.create!(title: "Inverted Order", replies_count: 2)

      assert_equal [2, 1], topic.where(title: "Inverted Order").order(:replies_count).pluck(:replies_count)
    end

    def test_implicit_order_uses_query_predicate_expressions
      topic = Class.new(ActiveRecord::Base) do
        self.table_name = "topics"
        attribute :id, InvertedInteger.new
      end
      lower_id = topic.create!(title: "Implicit Order")
      higher_id = topic.create!(title: "Implicit Order")
      scope = topic.where(title: "Implicit Order")

      assert_equal [higher_id, lower_id], [scope.first, scope.last]
    end

    def test_batch_cursors_use_query_predicate_expressions
      topic = Class.new(ActiveRecord::Base) do
        self.table_name = "topics"
        attribute :id, InvertedInteger.new
      end
      records = 3.times.map { topic.create!(title: "Batched Order") }
      batched_ids = topic.where(title: "Batched Order").find_each(batch_size: 2).map(&:id)

      assert_equal records.reverse.map(&:id), batched_ids
    end

    def test_in_order_of_uses_query_predicate_expressions
      topic = topic_model_with_title_type(LowerString.new)
      alpha = topic.create!(title: "Alpha")
      beta = topic.create!(title: "Beta")

      assert_equal [beta, alpha], topic.in_order_of(:title, ["BETA", "ALPHA"]).to_a
    end

    def test_bind_attribute_uses_query_predicate_expressions
      topic = topic_model_with_title_type(UnaccentedString.new)
      relation = topic.all
      predicate = relation.bind_attribute(:title, "CAFE") { |attribute, bind| attribute.eq(bind) }
      sql = relation.where(predicate).to_sql
      expected_sql = "SELECT #{quoted_topics}.* FROM #{quoted_topics} " \
        "WHERE #{normalized_title} = #{normalized_value("CAFE")}"

      assert_equal expected_sql, sql
    end

    def test_uniqueness_validation_uses_query_predicate_expressions
      topic = topic_model_with_unique_lower_title
      topic.create!(title: "Mixed Case")
      duplicate = topic.new(title: "MIXED CASE")

      assert_not_predicate duplicate, :valid?
      assert_predicate duplicate.errors[:title], :present?
    end

    def test_case_sensitive_uniqueness_validation_uses_query_predicate_expressions
      topic = topic_model_with_unique_lower_title(case_sensitive: true)
      topic.create!(title: "Case Sensitive Expression")

      assert_not_predicate topic.new(title: "CASE SENSITIVE EXPRESSION"), :valid?
    end

    def test_case_insensitive_uniqueness_validation_uses_query_predicate_expressions
      topic = topic_model_with_unique_lower_title(case_sensitive: false)
      topic.create!(title: "Case Insensitive Expression")

      assert_not_predicate topic.new(title: "CASE INSENSITIVE EXPRESSION"), :valid?
    end

    private
      def quoted_topics
        quote_table_name("topics")
      end

      def normalized_title
        "lower(custom_immutable_unaccent(#{quote_table_name("topics.title")}))"
      end

      def normalized_value(value)
        "lower(custom_immutable_unaccent(#{ActiveRecord::Base.lease_connection.quote(value)}))"
      end

      def topic_model_with_title_type(type)
        Class.new(ActiveRecord::Base) do
          self.table_name = "topics"
          attribute :title, type
        end
      end

      def topic_model_with_unique_lower_title(case_sensitive: nil)
        Class.new(ActiveRecord::Base) do
          self.table_name = "topics"
          attribute :title, LowerString.new
          validates :title, uniqueness: { case_sensitive: case_sensitive }.compact

          define_singleton_method(:name) { "NormalizedTopic" }
        end
      end
  end
end
