require "abstract_unit"

class ReloaderTest < ActiveSupport::TestCase
  def test_prepare_callback
    prepared = false
    reloader.to_prepare { prepared = true }

    assert !prepared
    reloader.prepare!
    assert prepared

    prepared = false
    reloader.wrap do
      assert prepared
      prepared = false
    end
    assert !prepared
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
    assert !invoked
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
