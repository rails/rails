require 'abstract_unit'

class ReloaderTests < ActiveSupport::TestCase
  Reloader   = ActionController::Reloader
  Dispatcher = ActionController::Dispatcher

  class MyBody < Array
    def initialize(&block)
      @on_close = block
    end

    def foo
      "foo"
    end

    def bar
      "bar"
    end

    def close
      @on_close.call if @on_close
    end
  end

  def setup
    @lock = Mutex.new
  end

  def test_it_reloads_the_application_before_yielding
    Dispatcher.expects(:reload_application)
    Reloader.run(@lock) do
      [200, { "Content-Type" => "text/html" }, [""]]
    end
  end

  def test_it_locks_before_yielding
    lock = DummyMutex.new
    Dispatcher.expects(:reload_application)
    Reloader.run(lock) do
      assert lock.locked?
      [200, { "Content-Type" => "text/html" }, [""]]
    end
    assert lock.locked?
  end

  def test_it_unlocks_upon_calling_close_on_body
    lock = DummyMutex.new
    Dispatcher.expects(:reload_application)
    headers, status, body = Reloader.run(lock) do
      [200, { "Content-Type" => "text/html" }, [""]]
    end
    body.close
    assert !lock.locked?
  end

  def test_it_unlocks_if_app_object_raises_exception
    lock = DummyMutex.new
    Dispatcher.expects(:reload_application)
    assert_raise(RuntimeError) do
      Reloader.run(lock) do
        raise "oh no!"
      end
    end
    assert !lock.locked?
  end

  def test_returned_body_object_always_responds_to_close
    status, headers, body = Reloader.run(@lock) do
      [200, { "Content-Type" => "text/html" }, [""]]
    end
    assert body.respond_to?(:close)
  end

  def test_returned_body_object_behaves_like_underlying_object
    status, headers, body = Reloader.run(@lock) do
      b = MyBody.new
      b << "hello"
      b << "world"
      [200, { "Content-Type" => "text/html" }, b]
    end
    assert_equal 2, body.size
    assert_equal "hello", body[0]
    assert_equal "world", body[1]
    assert_equal "foo", body.foo
    assert_equal "bar", body.bar
  end

  def test_it_calls_close_on_underlying_object_when_close_is_called_on_body
    close_called = false
    status, headers, body = Reloader.run(@lock) do
      b = MyBody.new do
        close_called = true
      end
      [200, { "Content-Type" => "text/html" }, b]
    end
    body.close
    assert close_called
  end

  def test_returned_body_object_responds_to_all_methods_supported_by_underlying_object
    status, headers, body = Reloader.run(@lock) do
      [200, { "Content-Type" => "text/html" }, MyBody.new]
    end
    assert body.respond_to?(:size)
    assert body.respond_to?(:each)
    assert body.respond_to?(:foo)
    assert body.respond_to?(:bar)
  end

  def test_it_doesnt_clean_up_the_application_after_call
    Dispatcher.expects(:cleanup_application).never
    status, headers, body = Reloader.run(@lock) do
      [200, { "Content-Type" => "text/html" }, MyBody.new]
    end
  end

  def test_it_cleans_up_the_application_when_close_is_called_on_body
    Dispatcher.expects(:cleanup_application)
    status, headers, body = Reloader.run(@lock) do
      [200, { "Content-Type" => "text/html" }, MyBody.new]
    end
    body.close
  end
end
