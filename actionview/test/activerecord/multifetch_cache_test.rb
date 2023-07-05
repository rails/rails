# frozen_string_literal: true

require "active_record_unit"

class MultifetchCacheTest < ActiveRecordTestCase
  fixtures :topics, :replies

  def setup
    view_paths = ActionController::Base.view_paths
    view_paths.each(&:clear_cache)

    @view = Class.new(ActionView::Base.with_empty_template_cache) do
      def view_cache_dependencies
        []
      end

      def combined_fragment_cache_key(key)
        [ :views, key ]
      end
    end.with_view_paths(view_paths, {})

    controller = ActionController::Base.new
    controller.perform_caching = true
    @view.controller = controller

    @cache_store_was = ActionView::PartialRenderer.collection_cache
    ActionView::PartialRenderer.collection_cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    ActionView::PartialRenderer.collection_cache = @cache_store_was
  end

  def test_only_preloading_for_records_that_miss_the_cache
    @view.render partial: "test/partial", collection: [topics(:rails)], cached: true

    @topics = Topic.preload(:replies)

    @view.render partial: "test/partial", collection: @topics, cached: true

    assert_not @topics.detect { |topic| topic.id == topics(:rails).id }.replies.loaded?
    assert     @topics.detect { |topic| topic.id != topics(:rails).id }.replies.loaded?
  end

  class InspectableStore < ActiveSupport::Cache::MemoryStore
    attr_reader :data
  end

  def test_fragments_are_stored_as_bare_strings
    cache = ActionView::PartialRenderer.collection_cache = InspectableStore.new
    @view.render partial: "test/partial", collection: [topics(:rails)], cached: true

    assert_not_predicate cache.data, :empty?
    cache.data.each_value do |entry|
      assert_equal String, entry.value.class
    end
  end
end
