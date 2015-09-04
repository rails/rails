require "cases/helper"
require "models/computer"
require "models/developer"
require "models/ship"
require "models/project"
require "models/topic"
require "models/post"
require "models/comment"

module ActiveRecord
  class CollectionCacheKeyTest < ActiveRecord::TestCase
    fixtures :developers, :projects, :developers_projects, :topics, :comments, :posts

    test "collection_cache_key on model" do
      assert_match(/\Adevelopers\/collection-digest-(\h+)\Z/, Developer.collection_cache_key)
    end

    test "collection_cache_key changes when old collection members are replaced" do
      project = Project.create
      project.developers.create(updated_at: 2.hours.ago, name: "anonymous")
      project.developers.create(updated_at: 4.hours.ago, name: "eponymous")

      key1 = project.developers.collection_cache_key

      project.developers.where(name: "eponymous").destroy_all
      project.developers.create(updated_at: 5.hours.ago, name: "anonymous")

      key2 = project.developers.collection_cache_key

      assert_not_equal key2, key1
    end

    test "cache_key for relation" do
      developers = Developer.where(name: "David")

      assert_match(/\Adevelopers\/collection-digest-(\h+)\Z/, developers.cache_key)

      /\Adevelopers\/collection-digest-(\h+)\Z/ =~ developers.cache_key

      assert_equal Digest::SHA256.hexdigest(developers.pluck(:id, :updated_at).flatten.join("-")), $1
    end

    test "it triggers at most one query" do
      developers =  Developer.where(name: "David")

      assert_queries(1) { developers.cache_key }
      assert_queries(0) { developers.cache_key }
    end

    test "it doesn't trigger any query if the relation is already loaded" do
      developers =  Developer.where(name: "David").load
      assert_queries(0) { developers.cache_key }
    end

    test "cache_key for empty relation" do
      developers = Developer.where(name: "Non Existent Developer")
      assert_match(/\Adevelopers\/collection-digest-(\h+)\Z/, developers.cache_key)
    end

    test "cache_key with custom timestamp column" do
      topics = Topic.where("title like ?", "%Topic%")

      expected_key_digest = Digest::SHA256.hexdigest(topics.pluck(:id, :written_on).flatten.join("-"))

      assert_match expected_key_digest, topics.cache_key(:written_on)
    end

    test "cache_key with unknown timestamp column" do
      topics = Topic.where("title like ?", "%Topic%")
      assert_raises(ActiveRecord::StatementInvalid) { topics.cache_key(:published_at) }
    end

    test "collection proxy provides a cache_key" do
      developers = projects(:active_record).developers
      assert_match /\Adevelopers\/collection-digest-(\h+)\Z/, developers.cache_key
    end
  end
end
