# frozen_string_literal: true

require "abstract_unit"

class CacheExpiryViewReloaderTest < ActiveSupport::TestCase
  # A no-op watcher class with the FileUpdateChecker API. Used instead of the
  # real ActiveSupport::FileUpdateChecker so we can assert exactly when the
  # watcher is materialized — its #initialize bumps a counter we can read.
  class CountingWatcher
    @@built = 0

    class << self
      def reset!
        @@built = 0
      end

      def built
        @@built
      end
    end

    def initialize(_files, _dirs = {}, &block)
      @block = block
      @@built += 1
    end

    def updated?
      false
    end

    def execute
      @block&.call
    end

    def execute_if_updated
      false
    end
  end

  def setup
    CountingWatcher.reset!
    @reloader = ActionView::CacheExpiry::ViewReloader.new(watcher: CountingWatcher)
  end

  test "create registers the hook on PathRegistry" do
    hooks = ActionView::PathRegistry.file_system_resolver_hooks
    initial_size = hooks.size

    reloader = ActionView::CacheExpiry::ViewReloader.create(watcher: CountingWatcher)

    assert_equal initial_size + 1, hooks.size
    assert_includes hooks, reloader.hook
  ensure
    hooks.delete(reloader.hook)
  end

  test "#updated? does not build a watcher when there are no view paths to watch" do
    ActionView::PathRegistry.stub(:all_file_system_resolvers, []) do
      assert_not @reloader.updated?
    end

    assert_equal 0, CountingWatcher.built
  end

  test "#rebuild_watcher is a no-op while @watcher has not been built" do
    @reloader.rebuild_watcher

    assert_equal 0, CountingWatcher.built
  end

  test "updated? builds a watcher once view paths are registered" do
    paths = []
    ActionView::PathRegistry.stub(:all_file_system_resolvers, paths) do
      @reloader.updated?
    end
    assert_equal 0, CountingWatcher.built

    paths << resolver_for_path("fixtures")
    ActionView::PathRegistry.stub(:all_file_system_resolvers, paths) do
      @reloader.updated?
    end

    assert_equal 1, CountingWatcher.built
  end

  test "#rebuild_watcher rebuilds the watcher after the first build" do
    paths = [resolver_for_path("fixtures")]
    ActionView::PathRegistry.stub(:all_file_system_resolvers, paths) do
      @reloader.updated?
    end

    assert_equal 1, CountingWatcher.built

    paths = paths << resolver_for_path("../fixtures/test")
    ActionView::PathRegistry.stub(:all_file_system_resolvers, paths) do
      @reloader.rebuild_watcher
    end

    assert_equal 2, CountingWatcher.built
  end

  test "#hook returns the bound method used for PathRegistry registration" do
    hooks = ActionView::PathRegistry.file_system_resolver_hooks
    hooks << @reloader.hook

    assert_includes hooks, @reloader.hook
  ensure
    hooks.delete(@reloader.hook)
  end

  test "#deactivate removes the hook from PathRegistry" do
    hooks = ActionView::PathRegistry.file_system_resolver_hooks
    hooks << @reloader.hook

    @reloader.deactivate

    assert_not_includes hooks, @reloader.hook
  ensure
    hooks.delete(@reloader.hook)
  end

  test "#deactivate is idempotent" do
    hooks = ActionView::PathRegistry.file_system_resolver_hooks
    initial_size = hooks.size
    hooks << @reloader.hook

    @reloader.deactivate
    @reloader.deactivate

    assert_equal initial_size, hooks.size
  ensure
    hooks.delete(@reloader.hook)
  end

  private
    def resolver_for_path(path)
      ActionView::PathRegistry.cast_file_system_resolvers(path).first
    end
end
