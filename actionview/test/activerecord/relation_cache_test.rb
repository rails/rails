require "active_record_unit"

class RelationCacheTest <  ActionView::TestCase
  tests ActionView::Helpers::CacheHelper

  def setup
    @virtual_path = "path"
    controller.cache_store = ActiveSupport::Cache::MemoryStore.new
  end

  def test_cache_relation_other
    cache(Project.all){ concat("Hello World") }
    assert_equal "Hello World", controller.cache_store.read("views/projects-#{Project.count}/")
  end

  def view_cache_dependencies; end

end
