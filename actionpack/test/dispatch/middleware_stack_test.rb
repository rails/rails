# frozen_string_literal: true

require "abstract_unit"

class MiddlewareStackTest < ActiveSupport::TestCase
  class Base
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    end
  end

  class FooMiddleware < Base; end
  class BarMiddleware < Base; end
  class BazMiddleware < Base; end
  class HiyaMiddleware < Base; end
  class BlockMiddleware < Base
    attr_reader :block
    def initialize(app, &block)
      super(app)
      @block = block
    end
  end

  def setup
    @stack = ActionDispatch::MiddlewareStack.new
    @stack.use FooMiddleware
    @stack.use BarMiddleware
  end

  def test_delete_works
    assert_difference "@stack.size", -1 do
      @stack.delete FooMiddleware
    end
  end

  test "use should push middleware as class onto the stack" do
    assert_difference "@stack.size" do
      @stack.use BazMiddleware
    end
    assert_equal BazMiddleware, @stack.last.klass
  end

  test "use should push middleware class with arguments onto the stack" do
    assert_difference "@stack.size" do
      @stack.use BazMiddleware, true, foo: "bar"
    end
    assert_equal BazMiddleware, @stack.last.klass
    assert_equal([true, { foo: "bar" }], @stack.last.args)
  end

  test "use should push middleware class with block arguments onto the stack" do
    proc = Proc.new { }
    assert_difference "@stack.size" do
      @stack.use(BlockMiddleware, &proc)
    end
    assert_equal BlockMiddleware, @stack.last.klass
    assert_equal proc, @stack.last.block
  end

  test "insert inserts middleware at the integer index" do
    @stack.insert(1, BazMiddleware)
    assert_equal BazMiddleware, @stack[1].klass
  end

  test "insert_after inserts middleware after the integer index" do
    @stack.insert_after(1, BazMiddleware)
    assert_equal BazMiddleware, @stack[2].klass
  end

  test "insert_before inserts middleware before another middleware class" do
    @stack.insert_before(BarMiddleware, BazMiddleware)
    assert_equal BazMiddleware, @stack[1].klass
  end

  test "insert_after inserts middleware after another middleware class" do
    @stack.insert_after(BarMiddleware, BazMiddleware)
    assert_equal BazMiddleware, @stack[2].klass
  end

  test "swaps one middleware out for another" do
    assert_equal FooMiddleware, @stack[0].klass
    @stack.swap(FooMiddleware, BazMiddleware)
    assert_equal BazMiddleware, @stack[0].klass
  end

  test "swaps one middleware out for same middleware class" do
    assert_equal FooMiddleware, @stack[0].klass
    @stack.swap(FooMiddleware, FooMiddleware, Proc.new { |env| [500, {}, ["error!"]] })
    assert_equal FooMiddleware, @stack[0].klass
  end

  test "move moves middleware at the integer index" do
    @stack.move(0, BarMiddleware)
    assert_equal BarMiddleware, @stack[0].klass
    assert_equal FooMiddleware, @stack[1].klass
  end

  test "move requires the moved middleware to be in the stack" do
    assert_raises RuntimeError do
      @stack.move(0, BazMiddleware)
    end
  end

  test "move preserves the arguments of the moved middleware" do
    @stack.use BazMiddleware, true, foo: "bar"
    @stack.move_before(FooMiddleware, BazMiddleware)

    assert_equal [true, foo: "bar"], @stack.first.args
  end

  test "move_before moves middleware before another middleware class" do
    @stack.move_before(FooMiddleware, BarMiddleware)
    assert_equal BarMiddleware, @stack[0].klass
    assert_equal FooMiddleware, @stack[1].klass
  end

  test "move_after requires the moved middleware to be in the stack" do
    assert_raises RuntimeError do
      @stack.move_after(BarMiddleware, BazMiddleware)
    end
  end

  test "move_after moves middleware after the integer index" do
    @stack.insert_after(BarMiddleware, BazMiddleware)
    @stack.move_after(0, BazMiddleware)
    assert_equal FooMiddleware, @stack[0].klass
    assert_equal BazMiddleware, @stack[1].klass
    assert_equal BarMiddleware, @stack[2].klass
  end

  test "move_after moves middleware after another middleware class" do
    @stack.insert_after(BarMiddleware, BazMiddleware)
    @stack.move_after(BarMiddleware, FooMiddleware)
    assert_equal BarMiddleware, @stack[0].klass
    assert_equal FooMiddleware, @stack[1].klass
    assert_equal BazMiddleware, @stack[2].klass
  end

  test "move_afters preserves the arguments of the moved middleware" do
    @stack.use BazMiddleware, true, foo: "bar"
    @stack.move_after(FooMiddleware, BazMiddleware)

    assert_equal [true, foo: "bar"], @stack[1].args
  end

  test "unshift adds a new middleware at the beginning of the stack" do
    @stack.unshift MiddlewareStackTest::BazMiddleware
    assert_equal BazMiddleware, @stack.first.klass
  end

  test "raise an error on invalid index" do
    assert_raise RuntimeError do
      @stack.insert(HiyaMiddleware, BazMiddleware)
    end

    assert_raise RuntimeError do
      @stack.insert_after(HiyaMiddleware, BazMiddleware)
    end
  end

  test "can check if Middleware are equal - Class" do
    assert_equal @stack.last, BarMiddleware
  end

  test "includes a class" do
    assert_equal true, @stack.include?(BarMiddleware)
  end

  test "can check if Middleware are equal - Middleware" do
    assert_equal @stack.last, @stack.last
  end

  test "instruments the execution of middlewares" do
    events = []

    subscriber = proc do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    ActiveSupport::Notifications.subscribed(subscriber, "process_middleware.action_dispatch") do
      app = @stack.build(proc { |env| [200, {}, []] })

      env = {}
      app.call(env)
    end

    assert_equal 2, events.count
    assert_equal ["MiddlewareStackTest::BarMiddleware", "MiddlewareStackTest::FooMiddleware"], events.map { |e| e.payload[:middleware] }
  end

  test "includes a middleware" do
    assert_equal true, @stack.include?(ActionDispatch::MiddlewareStack::Middleware.new(BarMiddleware, nil, nil))
  end
end
