require 'abstract_unit'
require 'fssm'
require "fileutils"
require "timeout"


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

module FSSM::Backends
  class Polling
    def initialize_with_low_latency(options={})
      initialize_without_low_latency(options.merge(:latency => 0.1))
    end
    alias_method_chain :initialize, :low_latency
  end
end

class FSSMFileWatcherTest < ActiveSupport::TestCase
  class FSSMBackend < ActiveSupport::FileWatcher::Backend
    def initialize(path, watcher)
      super

      monitor = FSSM::Monitor.new
      monitor.path(path, '**/*') do |p|
        p.update { |base, relative| trigger relative => :changed }
        p.delete { |base, relative| trigger relative => :deleted }
        p.create { |base, relative| trigger relative => :created }
      end

      @thread = Thread.new do
        monitor.run
      end
    end

    def stop
      @thread.kill
    end
  end

  def setup
    Thread.abort_on_exception = true

    @payload = []
    @triggered = false

    @watcher = ActiveSupport::FileWatcher.new

    @path = path = File.expand_path("../tmp", __FILE__)
    FileUtils.rm_rf path

    create "app/assets/main.scss", true
    create "app/assets/javascripts/foo.coffee", true
    create "app/assets/print.scss", true
    create "app/assets/videos.scss", true

    @backend = FSSMBackend.new(path, @watcher)

    @watcher.watch %r{^app/assets/.*\.scss$} do |pay|
      pay.each do |status, files|
        files.sort!
      end
      @payload << pay
      trigger
    end
  end

  def teardown
    @backend.stop
    Thread.abort_on_exception = false
  end

  def create(path, past = false)
    wait(past) do
      path = File.join(@path, path)
      FileUtils.mkdir_p(File.dirname(path))

      FileUtils.touch(path)
      File.utime(Time.now - 100, Time.now - 100, path) if past
    end
  end

  def change(path)
    wait do
      FileUtils.touch(File.join(@path, path))
    end
  end

  def delete(path)
    wait do
      FileUtils.rm(File.join(@path, path))
    end
  end

  def wait(past = false)
    yield
    return if past

    begin
      Timeout.timeout(1) do
        sleep 0.05 until @triggered
      end
    rescue Timeout::Error
    end

    @triggered = false
  end

  def trigger
    @triggered = true
  end

  def test_one_change
    change "app/assets/main.scss"
    assert_equal({:changed => ["app/assets/main.scss"]}, @payload.first)
  end

  def test_multiple_changes
    change "app/assets/main.scss"
    change "app/assets/javascripts/foo.coffee"
    assert_equal([{:changed => ["app/assets/main.scss"]}], @payload)
  end

  def test_multiple_changes_match
    change "app/assets/main.scss"
    change "app/assets/print.scss"
    change "app/assets/javascripts/foo.coffee"
    assert_equal([{:changed => ["app/assets/main.scss"]}, {:changed => ["app/assets/print.scss"]}], @payload)
  end

  def test_multiple_state_changes
    create "app/assets/new.scss"
    change "app/assets/print.scss"
    delete "app/assets/videos.scss"
    assert_equal([{:created => ["app/assets/new.scss"]}, {:changed => ["app/assets/print.scss"]}, {:deleted => ["app/assets/videos.scss"]}], @payload)
  end

  def test_more_blocks
    payload = []
    @watcher.watch %r{^config/routes\.rb$} do |pay|
      payload << pay
      trigger
    end

    create "config/routes.rb"
    assert_equal [{:created => ["config/routes.rb"]}], payload
    assert_equal [], @payload
  end

  def test_overlapping_watchers
    payload = []
    @watcher.watch %r{^app/assets/main\.scss$} do |pay|
      payload << pay
      trigger
    end

    change "app/assets/main.scss"
    change "app/assets/print.scss"
    assert_equal [{:changed => ["app/assets/main.scss"]}], payload
    assert_equal [{:changed => ["app/assets/main.scss"]}, {:changed => ["app/assets/print.scss"]}], @payload
  end
end
