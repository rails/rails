# frozen_string_literal: true

require "active_record_unit"

class MultifetchController < ActionController::Base
  ROUTES = test_routes do
    get :cached_true, to: "multifetch#cached_true"
    get :cached_proc, to: "multifetch#cached_proc"
  end

  def cached_true
    load_all_topics
    render partial: "test/multifetch", collection: @topics, as: :topic, cached: true
  end

  def cached_proc
    load_all_topics
    render partial: "test/multifetch", collection: @topics, as: :topic, cached: proc { |topic| [topic] }
  end

  private
    def load_all_topics
      @topics = Topic.preload(:replies)
    end
end

class MultifetchCacheTest < ActiveRecordTestCase
  tests MultifetchController
  fixtures :topics, :replies

  setup do
    Topic.update_all(updated_at: Time.now)
    @cache_store_was = ActionView::PartialRenderer.collection_cache
    ActionView::PartialRenderer.collection_cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    ActionView::PartialRenderer.collection_cache = @cache_store_was
  end

  def test_only_preloading_for_records_that_miss_the_cache
    Topic.update_all(title: "title")

    # The first request will not have anything cached, so we need to render all the records
    first_req = capture_sql do
      get :cached_true
    end
    assert_equal 3, @response.body.scan(/title/).length
    assert_equal 2, first_req.length
    assert_includes first_req.last, %(WHERE "replies"."topic_id" IN (?, ?, ?))

    Topic.first.update(updated_at: 1.hour.ago) # reset the cache key for this object

    # Now we only load the one record that we don't have a cached view for.
    second_req = capture_sql do
      get :cached_true
    end
    assert_equal 3, @response.body.scan(/title/).length
    assert_equal 2, second_req.length
    assert_equal first_req.first, second_req.first
    assert_includes second_req.last, %(WHERE "replies"."topic_id" = ?)
  end

  def test_preloads_all_records_if_using_cached_proc
    Topic.update_all(title: "title")

    # The first request will not have anything cached, so we need to render all the records
    first_req = capture_sql do
      get :cached_proc
    end
    assert_equal 3, @response.body.scan(/title/).length
    assert_equal 2, first_req.length
    assert_includes first_req.last, %(WHERE "replies"."topic_id" IN (?, ?, ?))

    Topic.first.update(updated_at: 1.hour.ago) # reset the cache key for this object

    # Since we are using a proc, we will preload the entire association.
    second_req = capture_sql do
      get :cached_proc
    end
    assert_equal 3, @response.body.scan(/title/).length
    assert_equal 2, second_req.length
    assert_equal first_req.first, second_req.first
    assert_includes second_req.last, %(WHERE "replies"."topic_id" IN (?, ?, ?))
  end

  class InspectableStore < ActiveSupport::Cache::MemoryStore
    attr_reader :data
  end

  def test_fragments_are_stored_as_bare_strings
    cache = ActionView::PartialRenderer.collection_cache = InspectableStore.new
    Topic.update_all(title: "title")
    get :cached_true

    assert_not_predicate cache.data, :empty?
    cache.data.each_value do |entry|
      assert_equal String, entry.value.class
    end
  end
end
