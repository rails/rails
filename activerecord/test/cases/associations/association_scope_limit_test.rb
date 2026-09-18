# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/post"
require "models/comment"

# Applying a `limit` or `offset` in an association's scope to each owner's own
# records takes a `LATERAL` subquery, and so is opt-in.
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
  end
end
