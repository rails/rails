# frozen_string_literal: true

require "active_record_unit"
require "active_record/testing/query_assertions"

class RelationCacheTest < ActionView::TestCase
  tests ActionView::Helpers::CacheHelper
  include ActiveRecord::Assertions::QueryAssertions

  def setup
    super
    view_paths     = ActionController::Base.view_paths
    lookup_context = ActionView::LookupContext.new(view_paths, {}, ["test"])
    @view_renderer = ActionView::Renderer.new(lookup_context)
    @virtual_path  = "path"
    @current_template = lookup_context.find "test/hello_world"

    controller.cache_store = ActiveSupport::Cache::MemoryStore.new
  end

  def test_cache_relation_other
    assert_queries_count(1) do
      cache(Project.all) { concat("Hello World") }
    end
    assert_equal "Hello World", controller.cache_store.read("views/test/hello_world:fa9482a68ce25bf7589b8eddad72f736/projects-#{Project.count}")
  end

  def view_cache_dependencies; []; end
end
