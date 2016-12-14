require "cases/helper"
require "models/computer"
require "models/developer"
require "models/project"
require "models/topic"
require "models/post"
require "models/comment"

module ActiveRecord
  class CollectionCacheKeyTest < ActiveRecord::TestCase
    fixtures :developers, :projects, :developers_projects, :topics, :comments, :posts

    test "collection_cache_key on model" do
      assert_match(/\Adevelopers\/query-(\h+)-(\d+)-(\d+)\Z/, Developer.collection_cache_key)
    end

    test "cache_key for relation" do
      developers = Developer.where(name: "David")
      last_developer_timestamp = developers.order(updated_at: :desc).first.updated_at

      assert_match(/\Adevelopers\/query-(\h+)-(\d+)-(\d+)\Z/, developers.cache_key)

      /\Adevelopers\/query-(\h+)-(\d+)-(\d+)\Z/ =~ developers.cache_key

      assert_equal Digest::MD5.hexdigest(developers.to_sql), $1
      assert_equal developers.count.to_s, $2
      assert_equal last_developer_timestamp.to_s(ActiveRecord::Base.cache_timestamp_format), $3
    end

    test "it triggers at most one query" do
      developers = Developer.where(name: "David")

      assert_queries(1) { developers.cache_key }
      assert_queries(0) { developers.cache_key }
    end

    test "it doesn't trigger any query if the relation is already loaded" do
      developers = Developer.where(name: "David").load
      assert_queries(0) { developers.cache_key }
    end

    test "relation cache_key changes when the sql query changes" do
      developers = Developer.where(name: "David")
      other_relation = Developer.where(name: "David").where("1 = 1")

      assert_not_equal developers.cache_key, other_relation.cache_key
    end

    test "cache_key for empty relation" do
      developers = Developer.where(name: "Non Existent Developer")
      assert_match(/\Adevelopers\/query-(\h+)-0\Z/, developers.cache_key)
    end

    test "cache_key with custom timestamp column" do
      topics = Topic.where("title like ?", "%Topic%")
      last_topic_timestamp = topics(:fifth).written_on.utc.to_s(:usec)
      assert_match(last_topic_timestamp, topics.cache_key(:written_on))
    end

    test "cache_key with unknown timestamp column" do
      topics = Topic.where("title like ?", "%Topic%")
      assert_raises(ActiveRecord::StatementInvalid) { topics.cache_key(:published_at) }
    end

    test "collection proxy provides a cache_key" do
      developers = projects(:active_record).developers
      assert_match(/\Adevelopers\/query-(\h+)-(\d+)-(\d+)\Z/, developers.cache_key)
    end

    test "cache_key for loaded collection with zero size" do
      Comment.delete_all
      posts = Post.includes(:comments)
      empty_loaded_collection = posts.first.comments

      assert_match(/\Acomments\/query-(\h+)-0\Z/, empty_loaded_collection.cache_key)
    end

    test "cache_key for queries with offset which return 0 rows" do
      developers = Developer.offset(20)
      assert_match(/\Adevelopers\/query-(\h+)-0\Z/, developers.cache_key)
    end

    test "cache_key with a relation having selected columns" do
      developers = Developer.select(:salary)

      assert_match(/\Adevelopers\/query-(\h+)-(\d+)-(\d+)\Z/, developers.cache_key)
    end
  end
end
