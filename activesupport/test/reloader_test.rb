# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/testing/ractors_assertions"

class ReloaderTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::RactorsAssertions

  def test_prepare_callback
    prepared = completed = false
    reloader.to_prepare { prepared = true }
    reloader.to_complete { completed = true }

    assert_not prepared
    assert_not completed
    reloader.prepare!
    assert prepared
    assert_not completed

    prepared = false
    reloader.wrap do
      assert prepared
      prepared = false
    end
    assert_not prepared
  end

  def test_prepend_prepare_callback
    i = 10
    reloader.to_prepare { i += 1 }
    reloader.to_prepare(prepend: true) { i = 0 }

    reloader.prepare!
    assert_equal 1, i
  end

  def test_only_run_when_check_passes
    r = new_reloader { true }
    invoked = false
    r.to_run { invoked = true }
    r.wrap { }
    assert invoked

    r = new_reloader { false }
    invoked = false
    r.to_run { invoked = true }
    r.wrap { }
    assert_not invoked
  end

  def test_full_reload_sequence
    called = []
    reloader.to_prepare { called << :prepare }
    reloader.to_run { called << :reloader_run }
    reloader.to_complete { called << :reloader_complete }
    reloader.executor.to_run { called << :executor_run }
    reloader.executor.to_complete { called << :executor_complete }

    reloader.wrap { }
    assert_equal [:executor_run, :reloader_run, :prepare, :reloader_complete, :executor_complete], called

    called = []
    reloader.reload!
    assert_equal [:executor_run, :reloader_run, :prepare, :reloader_complete, :executor_complete, :prepare], called

    reloader.check = lambda { false }

    called = []
    reloader.wrap { }
    assert_equal [:executor_run, :executor_complete], called

    called = []
    reloader.reload!
    assert_equal [:executor_run, :reloader_run, :prepare, :reloader_complete, :executor_complete, :prepare], called
  end

  def test_class_unload_block
    called = []
    reloader.before_class_unload { called << :before_unload }
    reloader.after_class_unload { called << :after_unload }
    reloader.to_run do
      class_unload! do
        called << :unload
      end
    end
    reloader.wrap { called << :body }

    assert_equal [:before_unload, :unload, :after_unload, :body], called
  end

  def test_report_errors_once
    reports = ErrorCollector.record do
      assert_raises RuntimeError do
        reloader.wrap do
          raise "Oops"
        end
      end
    end
    assert_equal 1, reports.size
  end

  def test_check_does_not_write_to_the_class_when_there_is_nothing_to_reload
    reloader = new_reloader { false }

    assert_not reloader.check!
    assert_not reloader.instance_variable_defined?(:@should_reload)

    reloader.check = lambda { true }

    assert reloader.check!
    assert reloader.instance_variable_get(:@should_reload)
  end

  def test_run_on_a_non_main_ractor_with_the_default_check
    reloader = Class.new(ActiveSupport::Reloader)

    assert on_ractor(reloader) { |r| r.run!.equal?(ActiveSupport::ExecutionWrapper::Null) }
  end

  private
    def new_reloader(&check)
      Class.new(ActiveSupport::Reloader).tap do |r|
        r.check = check
        r.executor = Class.new(ActiveSupport::Executor)
      end
    end

    def reloader
      @reloader ||= new_reloader { true }
    end
end
