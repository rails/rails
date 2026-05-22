# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/post"

class PreloaderTest < ActiveRecord::TestCase
  fixtures :authors, :posts

  def teardown
    ActiveRecord.preload_batch_size = nil
  end

  def test_preload_batch_size_defaults_to_nil
    assert_nil ActiveRecord.preload_batch_size
  end

  def test_preload_issues_single_query_by_default
    assert_queries_match(/SELECT.*FROM.*posts/i, count: 1) do
      Author.preload(:posts).to_a
    end
  end

  def test_preload_issues_batched_queries_when_batch_size_is_set
    ActiveRecord.preload_batch_size = 2

    # 3 authors with batch_size=2 produces 2 batches: [id1, id2] and [id3]
    assert_queries_match(/SELECT.*FROM.*posts/i, count: 2) do
      Author.preload(:posts).to_a
    end
  end

  def test_preload_with_batch_size_loads_correct_records
    ActiveRecord.preload_batch_size = 2

    authors = Author.preload(:posts).to_a

    assert_equal Author.count, authors.size

    authors.each do |author|
      expected_post_ids = Post.where(author_id: author.id).pluck(:id).sort
      assert_equal expected_post_ids, author.posts.map(&:id).sort
    end
  end

  def test_preload_via_preloader_issues_batched_queries_when_batch_size_is_set
    ActiveRecord.preload_batch_size = 2

    authors = Author.all.to_a

    assert_queries_match(/SELECT.*FROM.*posts/i, count: 2) do
      ActiveRecord::Associations::Preloader.new(records: authors, associations: :posts).call
    end
  end
end
