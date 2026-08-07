# frozen_string_literal: true

require "abstract_unit"

class RoutesReloaderTest < ActiveSupport::TestCase
  class FakeFileWatcher
    def initialize(&execute)
      @execute = execute
    end

    def new(*)
      self
    end

    def execute
      @execute.call
    end
  end

  test "loaded reports whether the routes are loaded" do
    reloader = build_reloader { }

    assert_not reloader.loaded

    assert_equal true, reloader.execute_unless_loaded
    assert reloader.loaded
  end

  test "a failed initial load is surfaced to waiting threads and retried" do
    draw_started = Queue.new
    draw_resume = Queue.new
    draws = 0

    reloader = build_reloader do
      draws += 1
      draw_started << true
      draw_resume.pop
      raise "invalid routes" if draws == 1
    end

    failing = Thread.new do
      reloader.execute_unless_loaded
    rescue RuntimeError => error
      error
    end
    draw_started.pop

    waiting = Thread.new { reloader.execute_unless_loaded }
    Thread.pass until waiting.stop?
    draw_resume << true

    assert_instance_of(RuntimeError, failing.value)

    # The waiting thread retries the draw rather than proceeding as if the
    # routes were loaded.
    draw_resume << true if draw_started.pop(timeout: 5)

    assert_equal(true, waiting.value)
    assert_equal(false, reloader.execute_unless_loaded)
  end

  private
    def build_reloader(&execute)
      file_watcher = FakeFileWatcher.new(&execute)
      Rails::Application::RoutesReloader.new(file_watcher: file_watcher)
    end
end
