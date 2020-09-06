# frozen_string_literal: true

require 'abstract_unit'

class ExecutorTest < ActiveSupport::TestCase
  class MyBody < Array
    def initialize(&block)
      @on_close = block
    end

    def foo
      'foo'
    end

    def bar
      'bar'
    end

    def close
      @on_close.call if @on_close
    end
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

  def test_returned_body_object_behaves_like_underlying_object
    body = call_and_return_body do
      b = MyBody.new
      b << 'hello'
      b << 'world'
      [200, { 'Content-Type' => 'text/html' }, b]
    end
    assert_equal 2, body.size
    assert_equal 'hello', body[0]
    assert_equal 'world', body[1]
    assert_equal 'foo', body.foo
    assert_equal 'bar', body.bar
  end

  def test_it_calls_close_on_underlying_object_when_close_is_called_on_body
    close_called = false
    body = call_and_return_body do
      b = MyBody.new do
        close_called = true
      end
      [200, { 'Content-Type' => 'text/html' }, b]
    end
    body.close
    assert close_called
  end

  def test_returned_body_object_responds_to_all_methods_supported_by_underlying_object
    body = call_and_return_body do
      [200, { 'Content-Type' => 'text/html' }, MyBody.new]
    end
    assert_respond_to body, :size
    assert_respond_to body, :each
    assert_respond_to body, :foo
    assert_respond_to body, :bar
  end

  def test_run_callbacks_are_called_before_close
    running = false
    executor.to_run { running = true }

    body = call_and_return_body
    assert running

    running = false
    body.close
    assert_not running
  end

  def test_complete_callbacks_are_called_on_close
    completed = false
    executor.to_complete { completed = true }

    body = call_and_return_body
    assert_not completed

    body.close
    assert completed
  end

  def test_complete_callbacks_are_called_on_exceptions
    completed = false
    executor.to_complete { completed = true }

    begin
      call_and_return_body do
        raise 'error'
      end
    rescue
    end

    assert completed
  end

  def test_callbacks_execute_in_shared_context
    result = false
    executor.to_run { @in_shared_context = true }
    executor.to_complete { result = @in_shared_context }

    call_and_return_body.close
    assert result
    assert_not defined?(@in_shared_context) # it's not in the test itself
  end

  private
    def call_and_return_body(&block)
      app = middleware(block || proc { [200, {}, 'response'] })
      _, _, body = app.call('rack.input' => StringIO.new(''))
      body
    end

    def middleware(inner_app)
      ActionDispatch::Executor.new(inner_app, executor)
    end

    def executor
      @executor ||= Class.new(ActiveSupport::Executor)
    end
end
