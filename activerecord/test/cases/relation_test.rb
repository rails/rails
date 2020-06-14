# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"
require "models/author"
require "models/rating"
require "models/categorization"

module ActiveRecord
  class RelationTest < ActiveRecord::TestCase
    fixtures :posts, :comments, :authors, :author_addresses, :ratings, :categorizations

    def test_construction
      relation = Relation.new(FakeKlass, table: :b)
      assert_equal FakeKlass, relation.klass
      assert_equal :b, relation.table
      assert_not relation.loaded, "relation is not loaded"
    end

    def test_responds_to_model_and_returns_klass
      relation = Relation.new(FakeKlass)
      assert_equal FakeKlass, relation.model
    end

    def test_initialize_single_values
      relation = Relation.new(FakeKlass)
      (Relation::SINGLE_VALUE_METHODS - [:create_with]).each do |method|
        assert_nil relation.send("#{method}_value"), method.to_s
      end
      value = relation.create_with_value
      assert_equal({}, value)
      assert_predicate value, :frozen?
    end

    def test_multi_value_initialize
      relation = Relation.new(FakeKlass)
      Relation::MULTI_VALUE_METHODS.each do |method|
        values = relation.send("#{method}_values")
        assert_equal [], values, method.to_s
        assert_predicate values, :frozen?, method.to_s
      end
    end

    def test_extensions
      relation = Relation.new(FakeKlass)
      assert_equal [], relation.extensions
    end

    def test_empty_where_values_hash
      relation = Relation.new(FakeKlass)
      assert_equal({}, relation.where_values_hash)
    end

    def test_where_values_hash_with_in_clause
      relation = Relation.new(Post)
      relation.where!(title: ["foo", "bar", "hello"])

      assert_equal({ "title" => ["foo", "bar", "hello"] }, relation.where_values_hash)
    end

    def test_has_values
      relation = Relation.new(Post)
      relation.where!(id: 10)
      assert_equal({ "id" => 10 }, relation.where_values_hash)
    end

    def test_values_wrong_table
      relation = Relation.new(Post)
      relation.where! Comment.arel_table[:id].eq(10)
      assert_equal({}, relation.where_values_hash)
    end

    def test_tree_is_not_traversed
      relation = Relation.new(Post)
      left     = relation.table[:id].eq(10)
      right    = relation.table[:id].eq(10)
      combine  = left.or(right)
      relation.where! combine
      assert_equal({}, relation.where_values_hash)
    end

    def test_scope_for_create
      relation = Relation.new(FakeKlass)
      assert_equal({}, relation.scope_for_create)
    end

    def test_create_with_value
      relation = Relation.new(Post)
      relation.create_with_value = { hello: "world" }
      assert_equal({ "hello" => "world" }, relation.scope_for_create)
    end

    def test_create_with_value_with_wheres
      relation = Relation.new(Post)
      assert_equal({}, relation.scope_for_create)

      relation.where!(id: 10)
      assert_equal({ "id" => 10 }, relation.scope_for_create)

      relation.create_with_value = { hello: "world" }
      assert_equal({ "hello" => "world", "id" => 10 }, relation.scope_for_create)
    end

    def test_empty_scope
      relation = Relation.new(Post)
      assert_predicate relation, :empty_scope?

      relation.merge!(relation)
      assert_predicate relation, :empty_scope?

      assert_not_predicate NullPost.all, :empty_scope?
      assert_not_predicate FirstPost.all, :empty_scope?
    end

    def test_bad_constants_raise_errors
      assert_raises(NameError) do
        ActiveRecord::Relation::HelloWorld
      end
    end

    def test_empty_eager_loading?
      relation = Relation.new(FakeKlass)
      assert_not_predicate relation, :eager_loading?
    end

    def test_eager_load_values
      relation = Relation.new(FakeKlass)
      relation.eager_load! :b
      assert_predicate relation, :eager_loading?
    end

    def test_references_values
      relation = Relation.new(FakeKlass)
      assert_equal [], relation.references_values
      relation = relation.references(:foo).references(:omg, :lol)
      assert_equal ["foo", "omg", "lol"], relation.references_values
    end

    def test_references_values_dont_duplicate
      relation = Relation.new(FakeKlass)
      relation = relation.references(:foo).references(:foo)
      assert_equal ["foo"], relation.references_values
    end

    test "merging a hash into a relation" do
      relation = Relation.new(Post)
      relation = relation.merge where: { name: :lol }, readonly: true

      assert_equal({ "name" => :lol }, relation.where_clause.to_h)
      assert_equal true, relation.readonly_value
    end

    test "merging an empty hash into a relation" do
      assert_equal Relation::WhereClause.empty, Relation.new(FakeKlass).merge({}).where_clause
    end

    test "merging a hash with unknown keys raises" do
      assert_raises(ArgumentError) { Relation::HashMerger.new(nil, omg: "lol") }
    end

    test "merging nil or false raises" do
      relation = Relation.new(FakeKlass)

      e = assert_raises(ArgumentError) do
        relation = relation.merge nil
      end

      assert_equal "invalid argument: nil.", e.message

      e = assert_raises(ArgumentError) do
        relation = relation.merge false
      end

      assert_equal "invalid argument: false.", e.message
    end

    test "#values returns a dup of the values" do
      relation = Relation.new(Post).where!(name: :foo)
      values   = relation.values

      values[:where] = nil
      assert_not_nil relation.where_clause
    end

    test "relations can be created with a values hash" do
      relation = Relation.new(FakeKlass, values: { select: [:foo] })
      assert_equal [:foo], relation.select_values
    end

    test "merging a hash interpolates conditions" do
      klass = Class.new(FakeKlass) do
        def self.sanitize_sql(args)
          raise unless args == ["foo = ?", "bar"]
          "foo = bar"
        end
      end

      relation = Relation.new(klass)
      relation.merge!(where: ["foo = ?", "bar"])
      assert_equal Relation::WhereClause.new(["foo = bar"]), relation.where_clause
    end

    def test_merging_readonly_false
      relation = Relation.new(FakeKlass)
      readonly_false_relation = relation.readonly(false)
      # test merging in both directions
      assert_equal false, relation.merge(readonly_false_relation).readonly_value
      assert_equal false, readonly_false_relation.merge(relation).readonly_value
    end

    def test_relation_merging_with_merged_joins_as_symbols
      special_comments_with_ratings = SpecialComment.joins(:ratings)
      posts_with_special_comments_with_ratings = Post.group("posts.id").joins(:special_comments).merge(special_comments_with_ratings)
      assert_equal({ 4 => 2 }, authors(:david).posts.merge(posts_with_special_comments_with_ratings).count)
    end

    def test_relation_merging_with_merged_symbol_joins_keeps_inner_joins
      queries = capture_sql { Author.joins(:posts).merge(Post.joins(:comments)).to_a }

      nb_inner_join = queries.sum { |sql| sql.scan(/INNER\s+JOIN/i).size }
      assert_equal 2, nb_inner_join, "Wrong amount of INNER JOIN in query"
      assert queries.none? { |sql| /LEFT\s+(OUTER)?\s+JOIN/i.match?(sql) }, "Shouldn't have any LEFT JOIN in query"
    end

    def test_relation_merging_with_merged_symbol_joins_has_correct_size_and_count
      # Has one entry per comment
      merged_authors_with_commented_posts_relation = Author.joins(:posts).merge(Post.joins(:comments))

      post_ids_with_author = Post.joins(:author).pluck(:id)
      manual_comments_on_post_that_have_author = Comment.where(post_id: post_ids_with_author).pluck(:id)

      assert_equal manual_comments_on_post_that_have_author.size, merged_authors_with_commented_posts_relation.count
      assert_equal manual_comments_on_post_that_have_author.size, merged_authors_with_commented_posts_relation.to_a.size
    end

    def test_relation_merging_with_merged_symbol_joins_is_aliased
      categorizations_with_authors = Categorization.joins(:author)
      queries = capture_sql { Post.joins(:author, :categorizations).merge(Author.select(:id)).merge(categorizations_with_authors).to_a }

      nb_inner_join = queries.sum { |sql| sql.scan(/INNER\s+JOIN/i).size }
      assert_equal 3, nb_inner_join, "Wrong amount of INNER JOIN in query"

      # using `\W` as the column separator
      assert queries.any? { |sql| %r[INNER\s+JOIN\s+#{Regexp.escape(Author.quoted_table_name)}\s+\Wauthors_categorizations\W]i.match?(sql) }, "Should be aliasing the child INNER JOINs in query"
    end

    def test_relation_with_merged_joins_aliased_works
      categorizations_with_authors = Categorization.joins(:author)
      posts_with_joins_and_merges = Post.joins(:author, :categorizations)
                                        .merge(Author.select(:id)).merge(categorizations_with_authors)

      author_with_posts = Author.joins(:posts).ids
      categorizations_with_author = Categorization.joins(:author).ids
      posts_with_author_and_categorizations = Post.joins(:categorizations).where(author_id: author_with_posts, categorizations: { id: categorizations_with_author }).ids

      assert_equal posts_with_author_and_categorizations.size, posts_with_joins_and_merges.count
      assert_equal posts_with_author_and_categorizations.size, posts_with_joins_and_merges.to_a.size
    end

    def test_relation_merging_with_joins_as_join_dependency_pick_proper_parent
      post = Post.create!(title: "haha", body: "huhu")
      comment = post.comments.create!(body: "hu")
      3.times { comment.ratings.create! }

      relation = Post.joins(:comments).merge Comment.joins(:ratings)

      assert_equal 3, relation.where(id: post.id).pluck(:id).size
    end

    def test_merge_raises_with_invalid_argument
      assert_raises ArgumentError do
        relation = Relation.new(FakeKlass)
        relation.merge(true)
      end
    end

    def test_respond_to_for_non_selected_element
      post = Post.select(:title).first
      assert_not_respond_to post, :body, "post should not respond_to?(:body) since invoking it raises exception"

      silence_warnings { post = Post.select("'title' as post_title").first }
      assert_not_respond_to post, :title, "post should not respond_to?(:body) since invoking it raises exception"
    end

    def test_select_quotes_when_using_from_clause
      skip_if_sqlite3_version_includes_quoting_bug
      quoted_join = ActiveRecord::Base.connection.quote_table_name("join")
      selected = Post.select(:join).from(Post.select("id as #{quoted_join}")).map(&:join)
      assert_equal Post.pluck(:id), selected
    end

    def test_selecting_aliased_attribute_quotes_column_name_when_from_is_used
      skip_if_sqlite3_version_includes_quoting_bug
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = :test_with_keyword_column_name
        alias_attribute :description, :desc
      end
      klass.create!(description: "foo")

      assert_equal ["foo"], klass.select(:description).from(klass.all).map(&:desc)
      assert_equal ["foo"], klass.reselect(:description).from(klass.all).map(&:desc)
    end

    def test_relation_merging_with_merged_joins_as_strings
      join_string = "LEFT OUTER JOIN #{Rating.quoted_table_name} ON #{SpecialComment.quoted_table_name}.id = #{Rating.quoted_table_name}.comment_id"
      special_comments_with_ratings = SpecialComment.joins join_string
      posts_with_special_comments_with_ratings = Post.group("posts.id").joins(:special_comments).merge(special_comments_with_ratings)
      assert_equal({ 2 => 1, 4 => 3, 5 => 1 }, authors(:david).posts.merge(posts_with_special_comments_with_ratings).count)
    end

    def test_relation_merging_keeps_joining_order
      authors  = Author.where(id: 1)
      posts    = Post.joins(:author).merge(authors)
      comments = Comment.joins(:post).merge(posts)
      ratings  = Rating.joins(:comment).merge(comments)

      assert_equal 3, ratings.count
    end

    def test_relation_with_annotation_includes_comment_in_to_sql
      post_with_annotation = Post.where(id: 1).annotate("foo")
      assert_match %r{= 1 /\* foo \*/}, post_with_annotation.to_sql
    end

    def test_relation_with_annotation_includes_comment_in_sql
      post_with_annotation = Post.where(id: 1).annotate("foo")
      assert_sql(%r{/\* foo \*/}) do
        assert post_with_annotation.first, "record should be found"
      end
    end

    def test_relation_with_annotation_chains_sql_comments
      post_with_annotation = Post.where(id: 1).annotate("foo").annotate("bar")
      assert_sql(%r{/\* foo \*/ /\* bar \*/}) do
        assert post_with_annotation.first, "record should be found"
      end
    end

    def test_relation_with_annotation_filters_sql_comment_delimiters
      post_with_annotation = Post.where(id: 1).annotate("**//foo//**")
      assert_match %r{= 1 /\* foo \*/}, post_with_annotation.to_sql
    end

    def test_relation_with_annotation_includes_comment_in_count_query
      post_with_annotation = Post.annotate("foo")
      all_count = Post.all.to_a.count
      assert_sql(%r{/\* foo \*/}) do
        assert_equal all_count, post_with_annotation.count
      end
    end

    def test_relation_without_annotation_does_not_include_an_empty_comment
      log = capture_sql do
        Post.where(id: 1).first
      end

      assert_not_predicate log, :empty?
      assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?
    end

    def test_relation_with_optimizer_hints_filters_sql_comment_delimiters
      post_with_hint = Post.where(id: 1).optimizer_hints("**//BADHINT//**")
      assert_match %r{BADHINT}, post_with_hint.to_sql
      assert_no_match %r{\*/BADHINT}, post_with_hint.to_sql
      assert_no_match %r{\*//BADHINT}, post_with_hint.to_sql
      assert_no_match %r{BADHINT/\*}, post_with_hint.to_sql
      assert_no_match %r{BADHINT//\*}, post_with_hint.to_sql
      post_with_hint = Post.where(id: 1).optimizer_hints("/*+ BADHINT */")
      assert_match %r{/\*\+ BADHINT \*/}, post_with_hint.to_sql
    end

    def test_does_not_duplicate_optimizer_hints_on_merge
      escaped_table = Post.connection.quote_table_name("posts")
      expected = "SELECT /*+ OMGHINT */ #{escaped_table}.* FROM #{escaped_table}"
      query = Post.optimizer_hints("OMGHINT").merge(Post.optimizer_hints("OMGHINT")).to_sql
      assert_equal expected, query
    end

    class EnsureRoundTripTypeCasting < ActiveRecord::Type::Value
      def type
        :string
      end

      def cast(value)
        raise value unless value == "value from user"
        "cast value"
      end

      def deserialize(value)
        raise value unless value == "type cast for database"
        "type cast from database"
      end

      def serialize(value)
        raise value unless value == "cast value"
        "type cast for database"
      end
    end

    class UpdateAllTestModel < ActiveRecord::Base
      self.table_name = "posts"

      attribute :body, EnsureRoundTripTypeCasting.new
    end

    def test_update_all_goes_through_normal_type_casting
      UpdateAllTestModel.update_all(body: "value from user", type: nil) # No STI

      assert_equal "type cast from database", UpdateAllTestModel.first.body
    end

    def test_skip_preloading_after_arel_has_been_generated
      assert_nothing_raised do
        relation = Comment.all
        relation.arel
        relation.skip_preloading!
      end
    end

    def test_marshal_load_legacy_relation
      path = File.expand_path(
        "support/marshal_compatibility_fixtures/legacy_relation.dump",
        TEST_ROOT
      )
      assert_equal 11, Marshal.load(File.read(path)).size
    end

    test "no queries on empty IN" do
      assert_queries(0) do
        Post.where(id: []).load
      end
    end

    test "can unscope empty IN" do
      assert_queries(1) do
        Post.where(id: []).unscope(where: :id).load
      end
    end

    private
      def skip_if_sqlite3_version_includes_quoting_bug
        if sqlite3_version_includes_quoting_bug?
          skip <<-ERROR.squish
            You are using an outdated version of SQLite3 which has a bug in
            quoted column names. Please update SQLite3 and rebuild the sqlite3
            ruby gem
          ERROR
        end
      end

      def sqlite3_version_includes_quoting_bug?
        if current_adapter?(:SQLite3Adapter)
          selected_quoted_column_names = ActiveRecord::Base.connection.exec_query(
            'SELECT "join" FROM (SELECT id AS "join" FROM posts) subquery'
          ).columns
          ["join"] != selected_quoted_column_names
        end
      end
  end
end
