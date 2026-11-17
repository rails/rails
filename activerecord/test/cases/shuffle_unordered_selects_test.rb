# frozen_string_literal: true

require "cases/helper"
require "active_support/core_ext/object/with"
require "models/author"
require "models/post"
require "models/comment"

class ShuffleUnorderedSelectsTest < ActiveRecord::TestCase
  fixtures :authors, :author_addresses, :posts, :comments

  SAMPLES = 10

  test "unordered relations are shuffled" do
    natural = with_shuffle(false) { Post.all.map(&:id) }
    orders = with_shuffle(true) { sample { Post.all.map(&:id) } }

    assert_operator orders.size, :>, 1
    orders.each { |ids| assert_equal natural.sort, ids.sort }
  end

  test "unordered pluck is shuffled" do
    natural = with_shuffle(false) { Post.pluck(:id) }
    orders = with_shuffle(true) { sample { Post.pluck(:id) } }

    assert_operator orders.size, :>, 1
    orders.each { |ids| assert_equal natural.sort, ids.sort }
  end

  test "eager loaded associations are shuffled" do
    id = authors(:david).id
    natural = with_shuffle(false) { Author.eager_load(:posts).find(id).posts.map(&:id) }
    orders = with_shuffle(true) { sample { Author.eager_load(:posts).find(id).posts.map(&:id) } }

    assert_operator orders.size, :>, 1
    orders.each { |ids| assert_equal natural.sort, ids.sort }
  end

  test "asynchronous queries are shuffled" do
    natural = with_shuffle(false) { Post.pluck(:id) }
    orders = with_shuffle(true) { sample { Post.async_pluck(:id).value } }

    assert_operator orders.size, :>, 1
    orders.each { |ids| assert_equal natural.sort, ids.sort }
  end

  test "ordered relations are left alone" do
    natural = with_shuffle(false) { Post.order(:id).map(&:id) }

    assert_equal [natural], with_shuffle(true) { sample { Post.order(:id).map(&:id) } }
  end

  test "raw SQL is left alone" do
    sql = Post.all.to_sql
    natural = with_shuffle(false) { Post.find_by_sql(sql).map(&:id) }

    assert_equal [natural], with_shuffle(true) { sample { Post.find_by_sql(sql).map(&:id) } }
  end

  test "order dependent finders are unaffected" do
    with_shuffle(true) do
      assert_equal Post.order(:id).first, Post.first
      assert_equal Post.order(:id).last, Post.last
    end
  end

  test "counts are unaffected" do
    count = with_shuffle(false) { Post.count }

    assert_equal count, with_shuffle(true) { Post.count }
  end

  test "exists? is unaffected" do
    with_shuffle(true) do
      assert_predicate Post, :exists?
      assert_not_predicate Post.where(id: -1), :exists?
    end
  end

  test "associations loaded through the statement cache are not shuffled" do
    author = authors(:david)
    natural = with_shuffle(false) { author.posts.reload.map(&:id) }

    assert_equal [natural], with_shuffle(true) { sample { author.posts.reload.map(&:id) } }
  end

  test "queries running under the query cache are shuffled" do
    natural = with_shuffle(false) { Post.all.map(&:id) }

    with_shuffle(true) do
      Post.cache do
        assert_not_equal natural, Post.all.map(&:id)
        assert_equal natural.sort, Post.all.map(&:id).sort
      end
    end
  end

  test "a cached query is shuffled again on every read" do
    natural = with_shuffle(false) { Post.pluck(:id) }

    with_shuffle(true) do
      Post.cache do
        orders = sample { Post.pluck(:id) }

        assert_operator orders.size, :>, 1
        orders.each { |ids| assert_equal natural.sort, ids.sort }
      end
    end
  end

  test "raw SQL sharing a cache entry with a generated query is left alone" do
    sql = Post.all.to_sql
    natural = with_shuffle(false) { Post.find_by_sql(sql).map(&:id) }

    with_shuffle(true) do
      Post.cache do
        assert_not_equal natural, Post.all.map(&:id)
        assert_equal natural, Post.find_by_sql(sql).map(&:id)
      end
    end

    with_shuffle(true) do
      Post.cache do
        assert_equal natural, Post.find_by_sql(sql).map(&:id)
        assert_not_equal natural, Post.all.map(&:id)
      end
    end
  end

  private
    def with_shuffle(value, &block)
      ActiveRecord.with(shuffle_unordered_selects: value, &block)
    end

    def sample(&block)
      SAMPLES.times.map(&block).uniq
    end
end
