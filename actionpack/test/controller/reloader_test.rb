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

  def setup_and_return_body(app = lambda { })
    Dispatcher.expects(:reload_application)
    reloader = Reloader.new(app)
    headers, status, body = reloader.call({ })
    body
  end

  def test_it_reloads_the_application_before_the_request
    Dispatcher.expects(:reload_application)
    reloader = Reloader.new(lambda {
      [200, { "Content-Type" => "text/html" }, [""]]
    })
    reloader.call({ })
  end

  def test_returned_body_object_always_responds_to_close
    body = setup_and_return_body(lambda {
      [200, { "Content-Type" => "text/html" }, [""]]
    })
    assert body.respond_to?(:close)
  end

  def test_returned_body_object_behaves_like_underlying_object
    body = setup_and_return_body(lambda {
      b = MyBody.new
      b << "hello"
      b << "world"
      [200, { "Content-Type" => "text/html" }, b]
    })
    assert_equal 2, body.size
    assert_equal "hello", body[0]
    assert_equal "world", body[1]
    assert_equal "foo", body.foo
    assert_equal "bar", body.bar
  end

  def test_it_calls_close_on_underlying_object_when_close_is_called_on_body
    close_called = false
    body = setup_and_return_body(lambda {
      b = MyBody.new do
        close_called = true
      end
      [200, { "Content-Type" => "text/html" }, b]
    })
    body.close
    assert close_called
  end

  def test_returned_body_object_responds_to_all_methods_supported_by_underlying_object
    body = setup_and_return_body(lambda {
      [200, { "Content-Type" => "text/html" }, MyBody.new]
    })
    assert body.respond_to?(:size)
    assert body.respond_to?(:each)
    assert body.respond_to?(:foo)
    assert body.respond_to?(:bar)
  end

  def test_it_doesnt_clean_up_the_application_after_call
    Dispatcher.expects(:cleanup_application).never
    body = setup_and_return_body(lambda {
      [200, { "Content-Type" => "text/html" }, MyBody.new]
    })
  end

  def test_it_cleans_up_the_application_when_close_is_called_on_body
    Dispatcher.expects(:cleanup_application)
    body = setup_and_return_body(lambda {
      [200, { "Content-Type" => "text/html" }, MyBody.new]
    })
    body.close
  end
end
