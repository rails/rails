# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/post"
require "models/comment"

# Applying a `limit` or `offset` in an association's scope to each owner's own
# records takes a `LATERAL` subquery, and so is opt-in. Both loading strategies
# are covered here: `includes` picks between them, so they must agree.
class AssociationScopeLimitTest < ActiveRecord::TestCase
  fixtures :authors, :author_addresses, :posts, :comments

  setup do
    @respect_association_scope_limits = ActiveRecord.respect_association_scope_limits
    ActiveRecord.respect_association_scope_limits = true
  end

  teardown do
    ActiveRecord.respect_association_scope_limits = @respect_association_scope_limits
  end

  # Only adapters with a LATERAL join give each owner its own rows.
  if ActiveRecord::Base.lease_connection.supports_lateral_joins?
    def test_eager_load_association_with_limit_returns_per_owner_rows
      authors = Author.eager_load(:posts_sorted_by_id_limited).to_a
      assert_predicate authors, :any?

      authors.each do |author|
        expected = author.posts.order(:id).limit(1).to_a
        assert_equal expected, author.posts_sorted_by_id_limited,
          "expected #{author.name} to see its own limited post via eager_load"
      end
    end

    def test_eager_load_association_with_limit_greater_than_one_returns_per_owner_rows
      klass = Class.new(Author) do
        has_many :limited_posts, -> { order(:id).limit(2) }, class_name: "Post", foreign_key: :author_id

        def self.name
          "Author"
        end
      end

      klass.eager_load(:limited_posts).to_a.each do |author|
        expected = author.posts.order(:id).limit(2).to_a
        assert_equal expected, author.limited_posts
      end
    end

    def test_eager_load_association_with_offset_returns_per_owner_rows
      klass = Class.new(Author) do
        has_many :offset_posts, -> { order(:id).offset(1) }, class_name: "Post", foreign_key: :author_id

        def self.name
          "Author"
        end
      end

      klass.eager_load(:offset_posts).to_a.each do |author|
        expected = author.posts.order(:id).offset(1).to_a
        assert_equal expected, author.offset_posts
      end
    end

    # The lateral subquery has to stay joinable, for a nested eager load.
    def test_eager_load_nested_association_under_an_association_with_limit
      authors = Author.eager_load(posts_sorted_by_id_limited: :comments).to_a
      assert_predicate authors, :any?

      authors.each do |author|
        post = author.posts.order(:id).first
        assert_equal [post], author.posts_sorted_by_id_limited
        assert_equal post.comments.sort_by(&:id),
          author.posts_sorted_by_id_limited.first.comments.sort_by(&:id)
      end
    end

    # The limit sits on a link of the chain, not on its last reflection.
    def test_eager_load_through_an_association_with_limit
      authors = Author.eager_load(:unordered_comments).to_a
      assert_predicate authors, :any?

      authors.each do |author|
        expected = author.posts.order(:id).first.comments.to_a
        assert_equal expected.sort_by(&:id), author.unordered_comments.sort_by(&:id)
      end
    end

    # The limit sits on the source of the chain, so the lateral join
    # correlates on a table that was itself joined, not on the base one.
    def test_eager_load_an_association_whose_through_source_has_a_limit
      authors = Author.eager_load(:first_comments_of_posts).to_a
      assert_predicate authors, :any?

      authors.each do |author|
        expected = author.posts.order(:id).flat_map do |post|
          post.comments.order(:id).limit(1).to_a
        end
        assert_equal expected.sort_by(&:id), author.first_comments_of_posts.sort_by(&:id)
      end
    end

    def test_eager_load_association_with_limit_honors_an_outer_limit
      authors = Author.eager_load(:posts_sorted_by_id_limited).order(:id).limit(2).to_a

      assert_equal 2, authors.size
      authors.each do |author|
        assert_equal author.posts.order(:id).limit(1).to_a, author.posts_sorted_by_id_limited
      end
    end

    def test_joins_association_with_limit_matches_one_row_per_owner
      assert_equal Author.count, Author.joins(:posts_sorted_by_id_limited).count
    end

    def test_preload_association_with_limit_returns_per_owner_rows
      authors = Author.preload(:posts_sorted_by_id_limited).to_a
      assert_predicate authors, :any?

      authors.each do |author|
        expected = author.posts.order(:id).limit(1).to_a
        assert_equal expected, author.posts_sorted_by_id_limited,
          "expected #{author.name} to see its own limited post via preload"
      end
    end

    def test_preload_association_with_limit_greater_than_one_returns_per_owner_rows
      authors = Author.all.to_a
      preload_posts(authors, Post.order(:id).limit(2))

      authors.each do |author|
        expected = author.posts.order(:id).limit(2).to_a
        assert_equal expected, author.association(:posts).target
      end
    end

    def test_preload_association_with_offset_and_no_limit_returns_per_owner_rows
      authors = Author.all.to_a
      preload_posts(authors, Post.order(:id).offset(1))

      authors.each do |author|
        expected = author.posts.order(:id).offset(1).to_a
        assert_equal expected, author.association(:posts).target
      end
    end

    def test_preload_association_with_limit_honors_the_scope_order
      authors = Author.all.to_a
      preload_posts(authors, Post.order(id: :desc).limit(2))

      authors.each do |author|
        expected = author.posts.order(id: :desc).limit(2).to_a
        assert_equal expected, author.association(:posts).target
      end
    end

    def test_preload_association_with_limit_honors_a_custom_select
      authors = Author.all.to_a
      preload_posts(authors, Post.select(:id, :author_id, :title).order(:id).limit(2))

      authors.each do |author|
        expected = author.posts.order(:id).limit(2).map(&:id)
        target = author.association(:posts).target
        assert_equal expected, target.map(&:id)
        target.each do |post|
          assert_equal ["id", "author_id", "title"], post.attributes.keys
        end
      end
    end

    def test_preload_association_with_limit_orders_by_a_column_the_select_keeps
      authors = Author.all.to_a
      preload_posts(authors, Post.select(:id, :author_id, :title).order(:title).limit(2))

      authors.each do |author|
        expected = author.posts.order(:title).limit(2).map(&:id)
        assert_equal expected, author.association(:posts).target.map(&:id)
      end
    end

    def test_preload_association_with_limit_does_not_leak_internal_columns
      authors = Author.all.to_a
      preload_posts(authors, Post.order(:id).limit(2))

      posts = authors.flat_map { |author| author.association(:posts).target }
      assert_predicate posts, :any?
      posts.each do |post|
        assert_equal Post.column_names, post.attributes.keys
      end
    end

    # The correlation on the key column must not take the scope's own
    # condition on that column with it.
    def test_preload_association_with_limit_keeps_scope_conditions_on_the_key_column
      authors = Author.all.to_a
      david = authors.find { |author| author.id == authors(:david).id }
      preload_posts(authors, Post.where.not(author_id: david.id).order(:id).limit(2))

      assert_empty david.association(:posts).target
      authors.each do |author|
        expected = author.posts.where.not(author_id: david.id).order(:id).limit(2).to_a
        assert_equal expected, author.association(:posts).target
      end
    end

    # The outer query can only order by what the subquery projects. An order it
    # cannot repeat there still picks the right rows, so it must not be copied
    # out and must not raise.
    def test_preload_association_with_limit_when_the_order_is_not_projected
      [
        Post.select(:id, :author_id).order(:title).limit(2),
        Post.joins(:comments).order("comments.id").limit(2),
        Post.order("title DESC").limit(2),
      ].each do |scope|
        authors = Author.all.to_a

        assert_nothing_raised { preload_posts(authors, scope) }

        authors.each do |author|
          target = author.association(:posts).target
          assert target.all? { |post| post.author_id == author.id },
            "#{scope.to_sql} gave #{author.name} a post belonging to someone else"
          assert_operator target.size, :<=, 2,
            "#{scope.to_sql} gave #{author.name} more rows than the limit"
        end
      end
    end

    if ActiveRecord::Base.lease_connection.prepared_statements
      # Batches of the same size can then share a prepared statement.
      def test_preload_association_with_limit_passes_owner_keys_as_binds
        authors = Author.all.to_a
        sql = capture_sql { preload_posts(authors, Post.order(:title).limit(2)) }.last

        # Postgres renders binds as $1, $2, ...; normalize them so that their
        # digits are not mistaken for inlined owner keys.
        sql = sql.gsub(/\$\d+/, "?")
        authors.each do |author|
          assert_no_match(/\b#{author.id}\b/, sql,
            "expected owner key #{author.id} to be sent as a bind parameter")
        end
      end
    end

    def test_eager_load_association_with_limit_agrees_with_preload
      preloaded = Author.preload(:posts_sorted_by_id_limited).to_a
      eager_loaded = Author.eager_load(:posts_sorted_by_id_limited).to_a

      assert_equal preloaded.map { |author| author.posts_sorted_by_id_limited.map(&:id) },
        eager_loaded.map { |author| author.posts_sorted_by_id_limited.map(&:id) }
    end

    # A `references` flips `includes` from one strategy to the other, which
    # must not change what comes back.
    def test_includes_association_with_limit_agrees_with_references
      preloaded = Author.includes(:posts_sorted_by_id_limited).to_a
      eager_loaded = Author.includes(:posts_sorted_by_id_limited)
        .references(:posts_sorted_by_id_limited).to_a

      assert_equal preloaded.map { |author| author.posts_sorted_by_id_limited.map(&:id) },
        eager_loaded.map { |author| author.posts_sorted_by_id_limited.map(&:id) }
    end

    private
      def preload_posts(records, scope)
        ActiveRecord::Associations::Preloader.new(
          records: records, associations: :posts, scope: scope
        ).call
      end
  end
end
