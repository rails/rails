require 'abstract_unit'

class FileWatcherTest < ActiveSupport::TestCase
  class DumbBackend < ActiveSupport::FileWatcher::Backend
  end

  def setup
    @watcher = ActiveSupport::FileWatcher.new

    # In real life, the backend would take the path and use it to observe the file
    # system. In our case, we will manually trigger the events for unit testing,
    # so we can pass any path.
    @backend = DumbBackend.new("RAILS_WOOT", @watcher)

    @payload = []
    @watcher.watch %r{^app/assets/.*\.scss$} do |pay|
      pay.each do |status, files|
        files.sort!
      end
      @payload << pay
    end
  end

  def test_use_triple_equals
    fw = ActiveSupport::FileWatcher.new
    called = []
    fw.watch("some_arbitrary_file.rb") do |file|
      called << "omg"
    end
    fw.trigger(%w{ some_arbitrary_file.rb })
    assert_equal ['omg'], called
  end

  def test_one_change
    @backend.trigger("app/assets/main.scss" => :changed)
    assert_equal({:changed => ["app/assets/main.scss"]}, @payload.first)
  end

  def test_multiple_changes
    @backend.trigger("app/assets/main.scss" => :changed, "app/assets/javascripts/foo.coffee" => :changed)
    assert_equal([{:changed => ["app/assets/main.scss"]}], @payload)
  end

  def test_multiple_changes_match
    @backend.trigger("app/assets/main.scss" => :changed, "app/assets/print.scss" => :changed, "app/assets/javascripts/foo.coffee" => :changed)
    assert_equal([{:changed => ["app/assets/main.scss", "app/assets/print.scss"]}], @payload)
  end

  def test_multiple_state_changes
    @backend.trigger("app/assets/main.scss" => :created, "app/assets/print.scss" => :changed)
    assert_equal([{:changed => ["app/assets/print.scss"], :created => ["app/assets/main.scss"]}], @payload)
  end

  def test_more_blocks
    payload = []
    @watcher.watch %r{^config/routes\.rb$} do |pay|
      payload << pay
    end

    @backend.trigger "config/routes.rb" => :changed
    assert_equal [:changed => ["config/routes.rb"]], payload
    assert_equal [], @payload
  end

  def test_overlapping_watchers
    payload = []
    @watcher.watch %r{^app/assets/main\.scss$} do |pay|
      payload << pay
    end

    @backend.trigger "app/assets/print.scss" => :changed, "app/assets/main.scss" => :changed
    assert_equal [:changed => ["app/assets/main.scss"]], payload
    assert_equal [:changed => ["app/assets/main.scss", "app/assets/print.scss"]], @payload
  end
end
