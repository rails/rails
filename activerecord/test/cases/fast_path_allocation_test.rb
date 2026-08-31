# frozen_string_literal: true

require "cases/helper"

class FastPathAllocationTest < ActiveRecord::TestCase
  test "non-STI class is optimized" do
    klass = non_sti_class

    assert_not new_is_native?(klass)

    klass.load_schema

    assert_new_is_optimized(klass)
  end

  test "non-STI class with abstract superclass is optimized" do
    abstract = Class.new(ActiveRecord::Base) { self.abstract_class = true }
    klass = non_sti_class(abstract)

    assert_not new_is_native?(klass)

    klass.load_schema

    assert_new_is_optimized(klass)
  end

  test "STI class and its subclasses are not optimized" do
    base = sti_class
    sub = Class.new(base)

    assert_not new_is_native?(base)
    assert_not new_is_native?(sub)

    base.load_schema
    sub.load_schema

    assert_new_is_not_optimized(base)
    assert_new_is_not_optimized(sub)
  end

  test "class with redefined .new is not optimized" do
    klass = non_sti_class
    klass.singleton_class.define_method(:new) { |attributes = nil, &block| super(attributes, &block) }

    assert_not new_is_native?(klass)

    klass.load_schema

    assert_new_is_not_optimized(klass)
  end

  test "class with .new redefined in superclass is not optimized" do
    abstract = Class.new(ActiveRecord::Base) { self.abstract_class = true }
    abstract.singleton_class.define_method(:new) { |attributes = nil, &block| super(attributes, &block) }
    klass = non_sti_class(abstract)

    assert_not new_is_native?(klass)

    klass.load_schema

    assert_new_is_not_optimized(klass)
  end

  test "class with prepended .new is not optimized" do
    mod = Module.new do
      def new(attributes = nil, &block)
        super
      end
    end
    klass = non_sti_class
    klass.singleton_class.prepend(mod)

    assert_not new_is_native?(klass)

    klass.load_schema

    assert_new_is_not_optimized(klass)
  end

  test "deoptimization upon redefinition" do
    klass = non_sti_class

    assert_not new_is_native?(klass)

    klass.load_schema

    assert_new_is_optimized(klass)

    block_called = false
    klass.singleton_class.define_method(:new) { |attributes = nil, &block| block_called = true; super(attributes, &block) }
    klass.new

    assert block_called
    assert_new_is_not_optimized(klass)
  end

  test "deoptimization upon extension" do
    klass = non_sti_class

    assert_not new_is_native?(klass)

    klass.load_schema

    assert_new_is_optimized(klass)

    mod = Module.new do
      def new(attributes = nil, &block)
        @block_called = true
        super
      end
    end
    klass.singleton_class.prepend(mod)
    klass.new

    assert klass.instance_variable_get(:@block_called)
    assert_new_is_not_optimized(klass)
  end

  test "optimized class returns correct instance" do
    klass = non_sti_class

    assert_not new_is_native?(klass)

    klass.load_schema

    assert_new_is_optimized(klass)

    instance = klass.new

    assert_instance_of klass, instance
  end

  test "optimized class passes block to initialize" do
    klass = non_sti_class

    assert_not new_is_native?(klass)

    klass.load_schema

    assert_new_is_optimized(klass)

    block_called = false
    klass.new { |record| block_called = true }

    assert block_called
  end

  test "deoptimization after reset_column_information" do
    klass = non_sti_class

    assert_not new_is_native?(klass)

    klass.load_schema

    assert_new_is_optimized(klass)

    klass.reset_column_information

    assert_not new_is_native?(klass)
  end

  test "reoptimization after schema reload" do
    klass = non_sti_class

    assert_not new_is_native?(klass)

    klass.load_schema

    assert_new_is_optimized(klass)

    klass.reset_column_information

    assert_not new_is_native?(klass)

    klass.load_schema

    assert_new_is_optimized(klass)
  end

  test "new_is_native? detects C methods" do
    assert new_is_native?(Class)
    assert_not new_is_native?(ActiveRecord::Base)
  end

  private
    def non_sti_class(base = ActiveRecord::Base)
      # "accounts" table (see test/schema/schema.rb) has no "type" column, so no STI
      Class.new(base) { self.table_name = "accounts" }
    end

    def sti_class
      # "companies" table (see test/schema/schema.rb) has a "type" column, enabling STI
      Class.new(ActiveRecord::Base) { self.table_name = "companies" }
    end

    def new_is_native?(klass)
      klass.method(:new).source_location.nil?
    end

    # this calls `new` as a side effect, so it should only be called as a post-condition (not a
    # pre-condition)
    def assert_new_is_not_optimized(klass)
      assert_not new_is_native?(klass)

      if RubyVM.stat.key?(:opt_new_miss) # ruby compiled with -DUSE_DEBUG_COUNTER=1
        miss_before = RubyVM.stat[:opt_new_miss]
        klass.new
        assert RubyVM.stat[:opt_new_miss] > miss_before, "opt_new_miss should have incremented"
      end

      ruby_new_calls = 0
      tp = TracePoint.new(:call) { |t| ruby_new_calls += 1 if t.method_id == :new }
      tp.enable { klass.new }
      assert ruby_new_calls > 0, "TracePoint should have observed a Ruby-level :call for .new"
    end

    # this calls `new` as a side effect, so it should only be called as a post-condition (not a
    # pre-condition)
    def assert_new_is_optimized(klass)
      assert new_is_native?(klass)

      if RubyVM.stat.key?(:opt_new_hit) # ruby compiled with -DUSE_DEBUG_COUNTER=1
        hit_before, miss_before = RubyVM.stat[:opt_new_hit], RubyVM.stat[:opt_new_miss]
        klass.new
        assert RubyVM.stat[:opt_new_hit] > hit_before, "opt_new_hit should have incremented"
        assert_equal miss_before, RubyVM.stat[:opt_new_miss], "opt_new_miss should not have changed"
      end

      ruby_new_calls = 0
      tp = TracePoint.new(:call) { |t| ruby_new_calls += 1 if t.method_id == :new }
      tp.enable { klass.new }
      assert_equal 0, ruby_new_calls, "TracePoint should not observe a Ruby-level :call for .new"
    end
end
