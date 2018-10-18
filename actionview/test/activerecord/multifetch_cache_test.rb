# frozen_string_literal: true

require "active_record_unit"
require "active_record/railties/collection_cache_association_loading"

ActionView::PartialRenderer.prepend(ActiveRecord::Railties::CollectionCacheAssociationLoading)

class MultifetchCacheTest < ActiveRecordTestCase
  fixtures :topics, :replies

  def setup
    view_paths = ActionController::Base.view_paths

    @view = Class.new(ActionView::Base) do
      def view_cache_dependencies
        []
      end

      def combined_fragment_cache_key(key)
        [ :views, key ]
      end
    end.new(view_paths, {})
  end

  def test_only_preloading_for_records_that_miss_the_cache
    @view.render partial: "test/partial", collection: [topics(:rails)], cached: true

    @topics = Topic.preload(:replies)

    @view.render partial: "test/partial", collection: @topics, cached: true

    assert_not @topics.detect { |topic| topic.id == topics(:rails).id }.replies.loaded?
    assert     @topics.detect { |topic| topic.id != topics(:rails).id }.replies.loaded?
  end
end
