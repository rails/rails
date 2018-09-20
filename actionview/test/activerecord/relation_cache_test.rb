# frozen_string_literal: true

require "active_record_unit"

class RelationCacheTest < ActionView::TestCase
  tests ActionView::Helpers::CacheHelper

  def setup
    view_paths     = ActionController::Base.view_paths
    lookup_context = ActionView::LookupContext.new(view_paths, {}, ["test"])
    @view_renderer = ActionView::Renderer.new(lookup_context)
    @virtual_path  = "path"

    controller.cache_store = ActiveSupport::Cache::MemoryStore.new
  end

  def test_cache_relation_other
    cache(Project.all) { concat("Hello World") }
    assert_equal "Hello World", controller.cache_store.read("views/path/projects-#{Project.count}")
  end

  def view_cache_dependencies; []; end
end
