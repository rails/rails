# frozen_string_literal: true

# This test verifies the behavior of polymorphic associations in queries with includes/preload/eager_load.
# Since polymorphic associations cannot be eager loaded (would raise EagerLoadPolymorphicError),
# this test ensures that Rails automatically falls back to preloading when appropriate,
# while still raising errors in cases where eager loading is explicitly requested.

require "cases/helper"
require "models/post"
require "models/author"
require "models/comment"

class PolymorphicAssociationLoadingTest < ActiveRecord::TestCase
  fixtures :posts, :authors, :comments

  def setup
    @post = posts(:welcome)
    @author = authors(:david)
    @comment = comments(:greetings)

    # Setup a polymorphic association for testing
    @comment.update(author_id: nil, author_type: "Author")
    @author.update(id: @comment.id)
  end

  def test_polymorphic_association_with_common_joins_and_includes
    # This test specifically addresses Issue #54981
    # Test case for when the same non-polymorphic association is used in both
    # joins and includes, alongside a polymorphic association in includes

    # Setup query where :post appears in both joins and includes,
    # and :author is a polymorphic association also included
    comments = Comment.joins(:post).includes(:post, :author)

    # This should not raise EagerLoadPolymorphicError
    assert_nothing_raised do
      comments.to_a
    end

    # Accessing the polymorphic association should not trigger additional queries
    comment = comments.first
    assert_no_queries do
      comment.author
    end
  end

  def test_polymorphic_association_with_joins_and_includes
    # This should preload the polymorphic association
    comments = Comment.joins(:post).includes(:post, :author)

    # This should not raise EagerLoadPolymorphicError
    comments.to_a

    # Accessing the polymorphic association should not trigger additional queries
    comment = comments.first
    assert_no_queries do
      comment.author
    end
  end

  def test_polymorphic_association_with_eager_load
    # This should raise EagerLoadPolymorphicError as we're explicitly trying to eager_load a polymorphic association
    assert_raises(ActiveRecord::EagerLoadPolymorphicError) do
      Comment.eager_load(:author).to_a
    end
  end

  def test_polymorphic_association_with_includes_and_references
    # Should raise EagerLoadPolymorphicError when using includes with references
    # on polymorphic associations
    assert_raises(ActiveRecord::EagerLoadPolymorphicError) do
      Comment.includes(:author).references(:author).to_a
    end
  end

  def test_deeply_nested_polymorphic_association
    # Setup a nested relation with a polymorphic association
    nested_comments = Comment.joins(:post).includes(post: { comments: :author })

    # This should not raise an error
    nested_comments.to_a

    # Accessing the nested polymorphic association should work without extra queries
    comment = nested_comments.first
    post = comment.post

    assert_no_queries do
      # Access the nested polymorphic association
      post.comments.first.author
    end
  end
end
