# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/proc"
require "active_support/core_ext/method"

class CallableTest < ActiveSupport::TestCase
  def test_none
    callable = ->() { }

    assert_parameters_valid(callable)
    assert_parameters_not_valid(callable, 1)
    assert_parameters_not_valid(callable, foo: 1)
  end

  def test_req
    callable = ->(req) { }

    assert_parameters_valid(callable, 1)
    assert_parameters_valid(callable, foo: 1)
    assert_parameters_not_valid(callable)
    assert_parameters_not_valid(callable, 1, 2)
  end

  def test_req_req
    callable = ->(req1, req2) { }

    assert_parameters_valid(callable, 1, 2)
    assert_parameters_valid(callable, 1, foo: 1)
    assert_parameters_not_valid(callable, 1)
    assert_parameters_not_valid(callable, 1, 2, 3)
  end

  def test_opt
    callable = ->(req, opt = nil) { }

    assert_parameters_valid(callable, 1)
    assert_parameters_valid(callable, 1, 2)
    assert_parameters_valid(callable, foo: 1)
    assert_parameters_valid(callable, 1, foo: 2)
    assert_parameters_not_valid(callable)
    assert_parameters_not_valid(callable, 1, 2, foo: 3)
    assert_parameters_not_valid(callable, 1, 2, 3)
  end

  def test_req_rest
    callable = ->(req, *rest) { }

    assert_parameters_valid(callable, 1)
    assert_parameters_valid(callable, 1, 2)
    assert_parameters_valid(callable, 1, 2, 3)
    assert_parameters_valid(callable, foo: 1)
    assert_parameters_valid(callable, 1, foo: 2)
    assert_parameters_not_valid(callable)
  end

  def test_key
    callable = ->(key: nil) { }

    assert_parameters_valid(callable)
    assert_parameters_valid(callable, key: 1)
    assert_parameters_not_valid(callable, 1)
    assert_parameters_not_valid(callable, 1, key: 2)
    assert_parameters_not_valid(callable, key: 1, foo: 2)
    assert_parameters_not_valid(callable, foo: 1)
  end

  def test_keyreq
    callable = ->(keyreq:) { }

    assert_parameters_valid(callable, keyreq: 1)
    assert_parameters_not_valid(callable)
    assert_parameters_not_valid(callable, 1)
    assert_parameters_not_valid(callable, 1, keyreq: 1)
    assert_parameters_not_valid(callable, keyreq: 1, foo: 2)
    assert_parameters_not_valid(callable, foo: 1)
  end

  def test_keyreq_keyrest
    callable = ->(keyreq:, **keyrest) { }

    assert_parameters_valid(callable, keyreq: 1)
    assert_parameters_valid(callable, keyreq: 1, foo: 2)
    assert_parameters_not_valid(callable)
    assert_parameters_not_valid(callable, 1)
    assert_parameters_not_valid(callable, 1, keyreq: 1)
    assert_parameters_not_valid(callable, foo: 1)
  end

  def test_nokey
    callable = ->(**nil) { }

    assert_parameters_valid(callable)
    assert_parameters_not_valid(callable, 1)
    assert_parameters_not_valid(callable, foo: 1)
  end

  def test_method_proc
    method = method(:dummy)
    [method, method.to_proc].each do |callable|
      assert_parameters_valid(callable, 1, keyreq: 2)
      assert_parameters_valid(callable, 1, 2, keyreq: 3, key: 4)
      assert_parameters_not_valid(callable)
      assert_parameters_not_valid(callable, keyreq: 1)
      assert_parameters_not_valid(callable, 1, 2, 3, keyreq: 1)
      assert_parameters_not_valid(callable, keyreq: 1)
      assert_parameters_not_valid(callable, 1, 2, key: 3)
      assert_parameters_not_valid(callable, 1, 2, keyreq: 3, key: 4, foo: 5)
    end
  end

  def dummy(req, opt = nil, keyreq:, key: nil)
  end

  def test_incompatibility_warning
    callable = ->() { }
    callable.stub(:call, 1) do
      exception = assert_raises RuntimeError do
        callable.validate_parameters(1)
      end

      assert_equal "parameters_valid? not in sync with call - Proc has been invoked!", exception.message
    end
  end

  if RUBY_VERSION < "3"

    def assert_parameters_valid(callable, *args)
      assert callable.parameters_valid?(*args), "parameters_valid? to be true"
      assert_nothing_raised do
        callable.call(*args)
        callable.validate_parameters(*args)
      end
    end

    def assert_parameters_not_valid(callable, *args)
      assert_not callable.parameters_valid?(*args), "parameters_valid? to be false"
      assert_raises ArgumentError do
        callable.call(*args)
      end
      assert_raises ArgumentError do
        callable.validate_parameters(*args)
      end
    end

  else

    def assert_parameters_valid(callable, *args, **kw_args)
      assert callable.parameters_valid?(*args, **kw_args), "parameters_valid? to be true"
      assert_nothing_raised do
        callable.call(*args, **kw_args)
        callable.validate_parameters(*args, **kw_args)
      end
    end

    def assert_parameters_not_valid(callable, *args, **kw_args)
      assert_not callable.parameters_valid?(*args, **kw_args), "parameters_valid? to be false"
      assert_raises ArgumentError do
        callable.call(*args, **kw_args)
      end
      assert_raises ArgumentError do
        callable.validate_parameters(*args, **kw_args)
      end
    end

  end
end
