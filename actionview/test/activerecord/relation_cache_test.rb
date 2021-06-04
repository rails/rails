# frozen_string_literal: true

require "active_record_unit"

class RelationCacheTest < ActionView::TestCase
  tests ActionView::Helpers::CacheHelper

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
    assert_queries(1) do
      cache(Project.all) { concat("Hello World") }
    end
    assert_equal "Hello World", controller.cache_store.read("views/test/hello_world:fa9482a68ce25bf7589b8eddad72f736/projects-#{Project.count}")
  end

  def view_cache_dependencies; []; end

  def assert_queries(num)
    ActiveRecord::Base.connection.materialize_transactions
    count = 0

    ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
      count += 1 unless ["SCHEMA", "TRANSACTION"].include? payload[:name]
    end

    result = yield
    assert_equal num, count, "#{count} instead of #{num} queries were executed."
    result
  end
end
