require 'abstract_unit'

class MiddlewareStackTest < ActiveSupport::TestCase
  class FooMiddleware; end
  class BarMiddleware; end
  class BazMiddleware; end
  class BlockMiddleware
    attr_reader :block
    def initialize(&block)
      @block = block
    end
  end

  def setup
    @stack = ActionDispatch::MiddlewareStack.new
    @stack.use FooMiddleware
    @stack.use BarMiddleware
  end

  test "use should push middleware as class onto the stack" do
    assert_difference "@stack.size" do
      @stack.use BazMiddleware
    end
    assert_equal BazMiddleware, @stack.last.klass
  end

  test "use should push middleware as a string onto the stack" do
    assert_difference "@stack.size" do
      @stack.use "MiddlewareStackTest::BazMiddleware"
    end
    assert_equal BazMiddleware, @stack.last.klass
  end

  test "use should push middleware as a symbol onto the stack" do
    assert_difference "@stack.size" do
      @stack.use :"MiddlewareStackTest::BazMiddleware"
    end
    assert_equal BazMiddleware, @stack.last.klass
  end

  test "use should push middleware class with arguments onto the stack" do
    assert_difference "@stack.size" do
      @stack.use BazMiddleware, true, :foo => "bar"
    end
    assert_equal BazMiddleware, @stack.last.klass
    assert_equal([true, {:foo => "bar"}], @stack.last.args)
  end

  test "use should push middleware class with block arguments onto the stack" do
    proc = Proc.new {}
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
    @stack.swap(FooMiddleware, FooMiddleware, Proc.new { |env| [500, {}, ['error!']] })
    assert_equal FooMiddleware, @stack[0].klass
  end

  test "unshift adds a new middleware at the beginning of the stack" do
    @stack.unshift :"MiddlewareStackTest::BazMiddleware"
    assert_equal BazMiddleware, @stack.first.klass
  end

  test "raise an error on invalid index" do
    assert_raise RuntimeError do
      @stack.insert("HiyaMiddleware", BazMiddleware)
    end

    assert_raise RuntimeError do
      @stack.insert_after("HiyaMiddleware", BazMiddleware)
    end
  end

  test "lazy evaluates middleware class" do
    assert_difference "@stack.size" do
      @stack.use "MiddlewareStackTest::BazMiddleware"
    end
    assert_equal BazMiddleware, @stack.last.klass
  end

  test "lazy compares so unloaded constants are not loaded" do
    @stack.use "UnknownMiddleware"
    @stack.use :"MiddlewareStackTest::BazMiddleware"
    assert @stack.include?("::MiddlewareStackTest::BazMiddleware")
  end
end
