# frozen_string_literal: true

require "abstract_unit"

class RoutesReloaderTest < ActiveSupport::TestCase
  test "a failed initial load is surfaced to waiting threads and retried" do
    reloader = Rails::Application::RoutesReloader.new
    draw_started = Queue.new
    draw_resume = Queue.new
    draws = 0

    updater = Object.new
    updater.define_singleton_method(:execute) do
      draws += 1
      draw_started << true
      draw_resume.pop
      raise "invalid routes" if draws == 1
    end
    reloader.instance_variable_set(:@updater, updater)

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
    assert_predicate(reloader, :loaded)
  end
end
