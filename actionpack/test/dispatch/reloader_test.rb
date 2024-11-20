# frozen_string_literal: true

require "abstract_unit"

class ReloaderTest < ActiveSupport::TestCase
  teardown do
    ActiveSupport::Reloader.reset_callbacks :prepare
    ActiveSupport::Reloader.reset_callbacks :complete
  end

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

  def test_prepare_callbacks
    a = b = c = nil
    reloader.to_prepare { |*args| a = b = c = 1 }
    reloader.to_prepare { |*args| b = c = 2 }
    reloader.to_prepare { |*args| c = 3 }

    # Ensure to_prepare callbacks are not run when defined
    assert_nil a || b || c

    # Run callbacks
    call_and_return_body

    assert_equal 1, a
    assert_equal 2, b
    assert_equal 3, c
  end

  def test_returned_body_object_always_responds_to_close
    body = call_and_return_body
    assert_respond_to body, :close
  end

  def test_returned_body_object_always_responds_to_close_even_if_called_twice
    body = call_and_return_body
    assert_respond_to body, :close
    body.close

    body = call_and_return_body
    assert_respond_to body, :close
    body.close
  end

  def test_condition_specifies_when_to_reload
    i, j = 0, 0, 0, 0

    reloader = reloader(lambda { i < 3 })
    reloader.to_prepare { |*args| i += 1 }
    reloader.to_complete { |*args| j += 1 }

    app = middleware(lambda { |env| [200, {}, []] }, reloader)
    env = Rack::MockRequest.env_for("", {})
    5.times do
      resp = app.call(env)
      resp[2].close
    end
    assert_equal 3, i
    assert_equal 3, j
  end

  def test_it_calls_close_on_underlying_object_when_close_is_called_on_body
    close_called = false
    body = call_and_return_body do
      b = MyBody.new do
        close_called = true
      end
      [200, { "content-type" => "text/html" }, b]
    end
    body.close
    assert close_called
  end

  def test_complete_callbacks_are_called_when_body_is_closed
    completed = false
    reloader.to_complete { completed = true }

    body = call_and_return_body
    assert_not completed

    body.close
    assert completed
  end

  def test_prepare_callbacks_arent_called_when_body_is_closed
    prepared = false
    reloader.to_prepare { prepared = true }

    body = call_and_return_body
    prepared = false

    body.close
    assert_not prepared
  end

  def test_complete_callbacks_are_called_on_exceptions
    completed = false
    reloader.to_complete { completed = true }

    begin
      call_and_return_body do
        raise "error"
      end
    rescue
    end

    assert completed
  end

  private
    def call_and_return_body(&block)
      app = block || proc { [200, {}, "response"] }
      env = Rack::MockRequest.env_for("", {})
      _, _, body = middleware(app).call(env)
      body
    end

    def middleware(inner_app, reloader = reloader())
      Rack::Lint.new(ActionDispatch::Reloader.new(Rack::Lint.new(inner_app), reloader))
    end

    def reloader(check = lambda { true })
      @reloader ||= begin
                      reloader = Class.new(ActiveSupport::Reloader)
                      reloader.check = check
                      reloader
                    end
    end
end
