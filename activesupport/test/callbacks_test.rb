# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/core_ext/kernel/singleton_class"

module CallbacksTest
  class Record
    include ActiveSupport::Callbacks

    define_callbacks :save

    def self.before_save(*filters, &blk)
      set_callback(:save, :before, *filters, &blk)
    end

    def self.after_save(*filters, &blk)
      set_callback(:save, :after, *filters, &blk)
    end

    class << self
      def callback_symbol(callback_method)
        method_name = :"#{callback_method}_method"
        define_method(method_name) do
          history << [callback_method, :symbol]
        end
        method_name
      end

      def callback_proc(callback_method)
        Proc.new { |model| model.history << [callback_method, :proc] }
      end

      def callback_object(callback_method)
        klass = Class.new
        klass.define_method(callback_method) do |model|
          model.history << [:"#{callback_method}_save", :object]
        end
        klass.new
      end
    end

    def history
      @history ||= []
    end
  end

  class CallbackClass
    def self.before(model)
      model.history << [:before_save, :class]
    end

    def self.after(model)
      model.history << [:after_save, :class]
    end
  end

  class Person < Record
    attr_accessor :save_fails

    [:before_save, :after_save].each do |callback_method|
      callback_method_sym = callback_method.to_sym
      public_send(callback_method, callback_symbol(callback_method_sym))
      public_send(callback_method, callback_proc(callback_method_sym))
      public_send(callback_method, callback_object(callback_method_sym.to_s.gsub(/_save/, "")))
      public_send(callback_method, CallbackClass)
      public_send(callback_method) { |model| model.history << [callback_method_sym, :block] }
    end

    def save
      run_callbacks :save do
        raise "inside save" if save_fails
      end
    end
  end

  class PersonSkipper < Person
    skip_callback :save, :before, :before_save_method, if: :yes
    skip_callback :save, :after,  :after_save_method, unless: :yes
    skip_callback :save, :after,  :after_save_method, if: :no
    skip_callback :save, :before, :before_save_method, unless: :no
    skip_callback :save, :before, CallbackClass, if: :yes
    def yes; true; end
    def no; false; end
  end

  class PersonForProgrammaticSkipping < Person
  end

  class ParentController
    include ActiveSupport::Callbacks

    define_callbacks :dispatch

    set_callback :dispatch, :before, :log, unless: proc { |c| c.action_name == :index || c.action_name == :show }
    set_callback :dispatch, :after, :log2

    attr_reader :action_name, :logger
    def initialize(action_name)
      @action_name, @logger = action_name, []
    end

    def log
      @logger << action_name
    end

    def log2
      @logger << action_name
    end

    def dispatch
      run_callbacks :dispatch do
        @logger << "Done"
      end
      self
    end
  end

  class Child < ParentController
    skip_callback :dispatch, :before, :log, if: proc { |c| c.action_name == :update }
    skip_callback :dispatch, :after, :log2
  end

  class OneTimeCompile < Record
    @@starts_true, @@starts_false = true, false

    def initialize
      super
    end

    before_save Proc.new { |r| r.history << [:before_save, :starts_true, :if] }, if: :starts_true
    before_save Proc.new { |r| r.history << [:before_save, :starts_false, :if] }, if: :starts_false
    before_save Proc.new { |r| r.history << [:before_save, :starts_true, :unless] }, unless: :starts_true
    before_save Proc.new { |r| r.history << [:before_save, :starts_false, :unless] }, unless: :starts_false

    def starts_true
      if @@starts_true
        @@starts_true = false
        return true
      end
      @@starts_true
    end

    def starts_false
      unless @@starts_false
        @@starts_false = true
        return false
      end
      @@starts_false
    end

    def save
      run_callbacks :save
    end
  end

  class OneTimeCompileTest < ActiveSupport::TestCase
    def test_optimized_first_compile
      around = OneTimeCompile.new
      around.save
      assert_equal [
        [:before_save, :starts_true, :if],
        [:before_save, :starts_true, :unless]
      ], around.history
    end
  end

  class AfterSaveConditionalPerson < Record
    after_save Proc.new { |r| r.history << [:after_save, :string1] }
    after_save Proc.new { |r| r.history << [:after_save, :string2] }
    def save
      run_callbacks :save
    end
  end

  class AfterSaveConditionalPersonCallbackTest < ActiveSupport::TestCase
    def test_after_save_runs_in_the_reverse_order
      person = AfterSaveConditionalPerson.new
      person.save
      assert_equal [
        [:after_save, :string2],
        [:after_save, :string1]
      ], person.history
    end
  end

  class ConditionalPerson < Record
    # proc
    before_save Proc.new { |r| r.history << [:before_save, :proc] }, if: Proc.new { |r| true }
    before_save Proc.new { |r| r.history << "b00m" }, if: Proc.new { |r| false }
    before_save Proc.new { |r| r.history << [:before_save, :proc] }, unless: Proc.new { |r| false }
    before_save Proc.new { |r| r.history << "b00m" }, unless: Proc.new { |r| true }
    # symbol
    before_save Proc.new { |r| r.history << [:before_save, :symbol] }, if: :yes
    before_save Proc.new { |r| r.history << "b00m" }, if: :no
    before_save Proc.new { |r| r.history << [:before_save, :symbol] }, unless: :no
    before_save Proc.new { |r| r.history << "b00m" }, unless: :yes
    # Combined if and unless
    before_save Proc.new { |r| r.history << [:before_save, :combined_symbol] }, if: :yes, unless: :no
    before_save Proc.new { |r| r.history << "b00m" }, if: :yes, unless: :yes

    def yes; true; end
    def other_yes; true; end
    def no; false; end
    def other_no; false; end

    def save
      run_callbacks :save
    end
  end

  class CleanPerson < ConditionalPerson
    reset_callbacks :save
  end

  class MySuper
    include ActiveSupport::Callbacks
    define_callbacks :save
  end

  class MySlate < MySuper
    attr_reader :history
    attr_accessor :save_fails

    def initialize
      @history = []
    end

    def save
      run_callbacks :save do
        raise "inside save" if save_fails
        @history << "running"
      end
    end

    def no; false; end
    def yes; true; end

    def method_missing(sym, *)
      case sym
      when /^log_(.*)/
        @history << $1
        nil
      when /^wrap_(.*)/
        @history << "wrap_#$1"
        yield
        @history << "unwrap_#$1"
        nil
      when /^double_(.*)/
        @history << "first_#$1"
        yield
        @history << "second_#$1"
        yield
        @history << "third_#$1"
      else
        super
      end
    end

    def respond_to_missing?(sym)
      sym.match?(/^(log|wrap)_/) || super
    end
  end

  class AroundPerson < MySlate
    set_callback :save, :before, :nope,           if: :no
    set_callback :save, :before, :nope,           unless: :yes
    set_callback :save, :after,  :tweedle
    set_callback :save, :before, proc { |m| m.history << "yup" }
    set_callback :save, :before, :nope,           if: proc { false }
    set_callback :save, :before, :nope,           unless: proc { true }
    set_callback :save, :before, :yup,            if: proc { true }
    set_callback :save, :before, :yup,            unless: proc { false }
    set_callback :save, :around, :tweedle_dum
    set_callback :save, :around, :w0tyes,         if: :yes
    set_callback :save, :around, :w0tno,          if: :no
    set_callback :save, :around, :tweedle_deedle

    def nope
      @history << "boom"
    end

    def yup
      @history << "yup"
    end

    def w0tyes
      @history << "w0tyes before"
      yield
      @history << "w0tyes after"
    end

    def w0tno
      @history << "boom"
      yield
    end

    def tweedle_dum
      @history << "tweedle dum pre"
      yield
      @history << "tweedle dum post"
    end

    def tweedle
      @history << "tweedle"
    end

    def tweedle_deedle
      @history << "tweedle deedle pre"
      yield
      @history << "tweedle deedle post"
    end
  end

  class AroundPersonResult < MySuper
    attr_reader :result

    set_callback :save, :after, :tweedle_1
    set_callback :save, :around, :tweedle_dum
    set_callback :save, :after, :tweedle_2

    def tweedle_dum
      @result = yield
    end

    def tweedle_1
      :tweedle_1
    end

    def tweedle_2
      :tweedle_2
    end

    def save
      run_callbacks :save do
        :running
      end
    end
  end

  class HyphenatedCallbacks
    include ActiveSupport::Callbacks
    define_callbacks :save
    attr_reader :stuff

    set_callback :save, :before, :action, if: :yes

    def yes() true end

    def action
      @stuff = "ACTION"
    end

    def save
      run_callbacks :save do
        @stuff
      end
    end
  end

  module ExtendModule
    def self.extended(base)
      base.class_eval do
        set_callback :save, :before, :record3
      end
    end
    def record3
      @recorder << 3
    end
  end

  module IncludeModule
    def self.included(base)
      base.class_eval do
        set_callback :save, :before, :record2
      end
    end
    def record2
      @recorder << 2
    end
  end

  class ExtendCallbacks
    include ActiveSupport::Callbacks

    define_callbacks :save
    set_callback :save, :before, :record1

    include IncludeModule

    def save
      run_callbacks :save
    end

    attr_reader :recorder

    def initialize
      @recorder = []
    end

    private
      def record1
        @recorder << 1
      end
  end

  class AroundCallbacksTest < ActiveSupport::TestCase
    def test_save_around
      around = AroundPerson.new
      around.save
      assert_equal [
        "yup", "yup",
        "tweedle dum pre",
        "w0tyes before",
        "tweedle deedle pre",
        "running",
        "tweedle deedle post",
        "w0tyes after",
        "tweedle dum post",
        "tweedle"
      ], around.history
    end
  end

  class DoubleYieldTest < ActiveSupport::TestCase
    class DoubleYieldModel < MySlate
      set_callback :save, :around, :wrap_outer
      set_callback :save, :around, :double_trouble
      set_callback :save, :around, :wrap_inner
    end

    def test_double_save
      double = DoubleYieldModel.new
      double.save
      assert_equal [
        "wrap_outer",
        "first_trouble",
        "wrap_inner",
        "running",
        "unwrap_inner",
        "second_trouble",
        "wrap_inner",
        "running",
        "unwrap_inner",
        "third_trouble",
        "unwrap_outer",
      ], double.history
    end
  end

  class CallStackTest < ActiveSupport::TestCase
    def test_tidy_call_stack
      around = AroundPerson.new
      around.save_fails = true

      exception = (around.save rescue $!)

      # Make sure we have the exception we're expecting
      assert_equal "inside save", exception.message

      call_stack = exception.backtrace_locations
      call_stack.pop caller_locations(0).size

      # Yes, this looks like an implementation test, but it's the least
      # obtuse way of asserting that there aren't a load of entries in
      # the call stack for each callback.
      #
      # If you've renamed a method, or squeezed more lines out, go ahead
      # and update this assertion. But if you're here because a
      # refactoring added new lines, please reconsider.

      # As shown here, our current budget is one line for run_callbacks
      # itself, plus N+1 lines where N is the number of :around
      # callbacks that have been invoked, if there are any (plus
      # whatever the callbacks do themselves, of course).

      assert_equal [
        "block in save",
        "block in run_callbacks",
        "tweedle_deedle",
        "block in run_callbacks",
        "w0tyes",
        "block in run_callbacks",
        "tweedle_dum",
        "block in run_callbacks",
        "run_callbacks",
        "save"
      ], call_stack.map(&:label)
    end

    def test_short_call_stack
      person = Person.new
      person.save_fails = true

      exception = (person.save rescue $!)

      # Make sure we have the exception we're expecting
      assert_equal "inside save", exception.message

      call_stack = exception.backtrace_locations
      call_stack.pop caller_locations(0).size

      # This budget much simpler: with no :around callbacks invoked,
      # there should be just one line. run_callbacks yields directly
      # back to its caller.

      assert_equal [
        "block in save",
        "run_callbacks",
        "save"
      ], call_stack.map(&:label)
    end
  end

  class AroundCallbackResultTest < ActiveSupport::TestCase
    def test_save_around
      around = AroundPersonResult.new
      around.save
      assert_equal :running, around.result
    end
  end

  class SkipCallbacksTest < ActiveSupport::TestCase
    def test_skip_person
      person = PersonSkipper.new
      assert_equal [], person.history
      person.save
      assert_equal [
        [:before_save, :proc],
        [:before_save, :object],
        [:before_save, :block],
        [:after_save, :block],
        [:after_save, :class],
        [:after_save, :object],
        [:after_save, :proc],
        [:after_save, :symbol]
      ], person.history
    end

    def test_skip_person_programmatically
      PersonForProgrammaticSkipping._save_callbacks.each do |save_callback|
        if "before" == save_callback.kind.to_s
          PersonForProgrammaticSkipping.skip_callback("save", save_callback.kind, save_callback.filter)
        end
      end
      person = PersonForProgrammaticSkipping.new
      assert_equal [], person.history
      person.save
      assert_equal [
        [:after_save, :block],
        [:after_save, :class],
        [:after_save, :object],
        [:after_save, :proc],
        [:after_save, :symbol]
      ], person.history
    end
  end

  class CallbacksTest < ActiveSupport::TestCase
    def test_save_person
      person = Person.new
      assert_equal [], person.history
      person.save
      assert_equal [
        [:before_save, :symbol],
        [:before_save, :proc],
        [:before_save, :object],
        [:before_save, :class],
        [:before_save, :block],
        [:after_save, :block],
        [:after_save, :class],
        [:after_save, :object],
        [:after_save, :proc],
        [:after_save, :symbol]
      ], person.history
    end
  end

  class ConditionalCallbackTest < ActiveSupport::TestCase
    def test_save_conditional_person
      person = ConditionalPerson.new
      person.save
      assert_equal [
        [:before_save, :proc],
        [:before_save, :proc],
        [:before_save, :symbol],
        [:before_save, :symbol],
        [:before_save, :combined_symbol],
      ], person.history
    end
  end

  class ResetCallbackTest < ActiveSupport::TestCase
    def test_save_conditional_person
      person = CleanPerson.new
      person.save
      assert_equal [], person.history
    end
  end

  class AbstractCallbackTerminator
    include ActiveSupport::Callbacks

    def self.set_save_callbacks
      set_callback :save, :before, :first
      set_callback :save, :before, :second
      set_callback :save, :around, :around_it
      set_callback :save, :before, :third
      set_callback :save, :after, :first
      set_callback :save, :around, :around_it
      set_callback :save, :after, :third
    end

    attr_reader :history, :saved, :halted, :callback_name
    def initialize
      @history = []
    end

    def around_it
      @history << "around1"
      yield
      @history << "around2"
    end

    def first
      @history << "first"
    end

    def second
      @history << "second"
      :halt
    end

    def third
      @history << "third"
    end

    def save
      run_callbacks :save do
        @saved = true
      end
    end

    def halted_callback_hook(filter, name)
      @halted = filter
      @callback_name = name
    end
  end

  class CallbackTerminator < AbstractCallbackTerminator
    define_callbacks :save, terminator: ->(_, result_lambda) { result_lambda.call == :halt }
    set_save_callbacks
  end

  class CallbackTerminatorSkippingAfterCallbacks < AbstractCallbackTerminator
    define_callbacks :save, terminator: ->(_, result_lambda) { result_lambda.call == :halt },
                            skip_after_callbacks_if_terminated: true
    set_save_callbacks
  end

  class CallbackDefaultTerminator < AbstractCallbackTerminator
    define_callbacks :save

    def second
      @history << "second"
      throw(:abort)
    end

    set_save_callbacks
  end

  class CallbackFalseTerminator < AbstractCallbackTerminator
    define_callbacks :save

    def second
      @history << "second"
      false
    end

    set_save_callbacks
  end

  class CallbackObject
    def before(caller)
      caller.record << "before"
    end

    def before_save(caller)
      caller.record << "before save"
    end

    def around(caller)
      caller.record << "around before"
      yield
      caller.record << "around after"
    end
  end

  class UsingObjectBefore
    include ActiveSupport::Callbacks

    define_callbacks :save
    set_callback :save, :before, CallbackObject.new

    attr_accessor :record
    def initialize
      @record = []
    end

    def save
      run_callbacks :save do
        @record << "yielded"
      end
    end
  end

  class UsingObjectAround
    include ActiveSupport::Callbacks

    define_callbacks :save
    set_callback :save, :around, CallbackObject.new

    attr_accessor :record
    def initialize
      @record = []
    end

    def save
      run_callbacks :save do
        @record << "yielded"
      end
    end
  end

  class CustomScopeObject
    include ActiveSupport::Callbacks

    define_callbacks :save, scope: [:kind, :name]
    set_callback :save, :before, CallbackObject.new

    attr_accessor :record
    def initialize
      @record = []
    end

    def save
      run_callbacks :save do
        @record << "yielded"
        "CallbackResult"
      end
    end
  end

  class OneTwoThreeSave
    include ActiveSupport::Callbacks

    define_callbacks :save

    attr_accessor :record

    def initialize
      @record = []
    end

    def save
      run_callbacks :save do
        @record << "yielded"
      end
    end

    def first
      @record << "one"
    end

    def second
      @record << "two"
    end

    def third
      @record << "three"
    end
  end

  class DuplicatingCallbacks < OneTwoThreeSave
    set_callback :save, :before, :first, :second
    set_callback :save, :before, :first, :third
  end

  class DuplicatingCallbacksInSameCall < OneTwoThreeSave
    set_callback :save, :before, :first, :second, :first, :third
  end

  class UsingObjectTest < ActiveSupport::TestCase
    def test_before_object
      u = UsingObjectBefore.new
      u.save
      assert_equal ["before", "yielded"], u.record
    end

    def test_around_object
      u = UsingObjectAround.new
      u.save
      assert_equal ["around before", "yielded", "around after"], u.record
    end

    def test_customized_object
      u = CustomScopeObject.new
      u.save
      assert_equal ["before save", "yielded"], u.record
    end

    def test_block_result_is_returned
      u = CustomScopeObject.new
      assert_equal "CallbackResult", u.save
    end
  end

  class CallbackTerminatorTest < ActiveSupport::TestCase
    def test_termination_skips_following_before_and_around_callbacks
      terminator = CallbackTerminator.new
      terminator.save
      assert_equal ["first", "second", "third", "first"], terminator.history
    end

    def test_termination_invokes_hook
      terminator = CallbackTerminator.new
      terminator.save
      assert_equal :second, terminator.halted
      assert_equal :save, terminator.callback_name
    end

    def test_block_never_called_if_terminated
      obj = CallbackTerminator.new
      obj.save
      assert_not obj.saved
    end
  end

  class CallbackTerminatorSkippingAfterCallbacksTest < ActiveSupport::TestCase
    def test_termination_skips_after_callbacks
      terminator = CallbackTerminatorSkippingAfterCallbacks.new
      terminator.save
      assert_equal ["first", "second"], terminator.history
    end
  end

  class CallbackDefaultTerminatorTest < ActiveSupport::TestCase
    def test_default_termination
      terminator = CallbackDefaultTerminator.new
      terminator.save
      assert_equal ["first", "second", "third", "first"], terminator.history
    end

    def test_default_termination_invokes_hook
      terminator = CallbackDefaultTerminator.new
      terminator.save
      assert_equal :second, terminator.halted
    end

    def test_block_never_called_if_abort_is_thrown
      obj = CallbackDefaultTerminator.new
      obj.save
      assert_not obj.saved
    end
  end

  class CallbackFalseTerminatorTest < ActiveSupport::TestCase
    def test_returning_false_does_not_halt_callback
      obj = CallbackFalseTerminator.new
      obj.save
      assert_nil obj.halted
      assert obj.saved
    end
  end

  class HyphenatedKeyTest < ActiveSupport::TestCase
    def test_save
      obj = HyphenatedCallbacks.new
      obj.save
      assert_equal "ACTION", obj.stuff
    end
  end

  class WriterSkipper < Person
    attr_accessor :age
    skip_callback :save, :before, :before_save_method, if: -> { age > 21 }
  end

  class WriterCallbacksTest < ActiveSupport::TestCase
    def test_skip_writer
      writer = WriterSkipper.new
      writer.age = 18
      assert_equal [], writer.history
      writer.save
      assert_equal [
        [:before_save, :symbol],
        [:before_save, :proc],
        [:before_save, :object],
        [:before_save, :class],
        [:before_save, :block],
        [:after_save, :block],
        [:after_save, :class],
        [:after_save, :object],
        [:after_save, :proc],
        [:after_save, :symbol]
      ], writer.history
    end
  end

  class ExtendCallbacksTest < ActiveSupport::TestCase
    def test_save
      model = ExtendCallbacks.new.extend ExtendModule
      model.save
      assert_equal [1, 2, 3], model.recorder
    end
  end

  class ExcludingDuplicatesCallbackTest < ActiveSupport::TestCase
    def test_excludes_duplicates_in_separate_calls
      model = DuplicatingCallbacks.new
      model.save
      assert_equal ["two", "one", "three", "yielded"], model.record
    end

    def test_excludes_duplicates_in_one_call
      model = DuplicatingCallbacksInSameCall.new
      model.save
      assert_equal ["two", "one", "three", "yielded"], model.record
    end
  end

  class CallbackProcTest < ActiveSupport::TestCase
    def build_class(callback)
      Class.new {
        include ActiveSupport::Callbacks
        define_callbacks :foo
        set_callback :foo, :before, callback
        def run; run_callbacks :foo; end
      }
    end

    def test_proc_arity_0
      calls = []
      klass = build_class(->() { calls << :foo })
      klass.new.run
      assert_equal [:foo], calls
    end

    def test_proc_arity_1
      calls = []
      klass = build_class(->(o) { calls << o })
      instance = klass.new
      instance.run
      assert_equal [instance], calls
    end

    def test_proc_arity_2
      assert_raises(ArgumentError) do
        klass = build_class(->(x, y) { })
        klass.new.run
      end
    end

    def test_proc_negative_called_with_empty_list
      calls = []
      klass = build_class(->(*args) { calls << args })
      klass.new.run
      assert_equal [[]], calls
    end
  end

  class ConditionalTests < ActiveSupport::TestCase
    def build_class(callback)
      Class.new {
        include ActiveSupport::Callbacks
        define_callbacks :foo
        set_callback :foo, :before, :foo, if: callback
        def foo; end
        def run; run_callbacks :foo; end
      }
    end

    # FIXME: do we really want to support classes as conditionals?  There were
    # no tests for it previous to this.
    def test_class_conditional_with_scope
      z = []
      callback = Class.new {
        define_singleton_method(:foo) { |o| z << o }
      }
      klass = Class.new {
        include ActiveSupport::Callbacks
        define_callbacks :foo, scope: [:name]
        set_callback :foo, :before, :foo, if: callback
        def run; run_callbacks :foo; end

        private
          def foo; end
      }
      object = klass.new
      object.run
      assert_equal [object], z
    end

    # FIXME: do we really want to support classes as conditionals?  There were
    # no tests for it previous to this.
    def test_class
      z = []
      klass = build_class Class.new {
        define_singleton_method(:before) { |o| z << o }
      }
      object = klass.new
      object.run
      assert_equal [object], z
    end

    def test_proc_negative_arity # passes an empty list if *args
      z = []
      object = build_class(->(*args) { z << args }).new
      object.run
      assert_equal [], z.flatten
    end

    def test_proc_arity0
      z = []
      object = build_class(->() { z << 0 }).new
      object.run
      assert_equal [0], z
    end

    def test_proc_arity1
      z = []
      object = build_class(->(x) { z << x }).new
      object.run
      assert_equal [object], z
    end

    def test_proc_arity2
      assert_raises(ArgumentError) do
        object = build_class(->(a, b) { }).new
        object.run
      end
    end
  end

  class ResetCallbackTest < ActiveSupport::TestCase
    def build_class(memo)
      klass = Class.new {
        include ActiveSupport::Callbacks
        define_callbacks :foo
        set_callback :foo, :before, :hello
        def run; run_callbacks :foo; end
      }
      klass.class_eval {
        define_method(:hello) { memo << :hi }
      }
      klass
    end

    def test_reset_callbacks
      events = []
      klass = build_class events
      klass.new.run
      assert_equal 1, events.length

      klass.reset_callbacks :foo
      klass.new.run
      assert_equal 1, events.length
    end

    def test_reset_impacts_subclasses
      events = []
      klass = build_class events
      subclass = Class.new(klass) { set_callback :foo, :before, :world }
      subclass.class_eval { define_method(:world) { events << :world } }

      subclass.new.run
      assert_equal 2, events.length

      klass.reset_callbacks :foo
      subclass.new.run
      assert_equal 3, events.length
    end
  end

  class CallbackTypeTest < ActiveSupport::TestCase
    def build_class(callback, n = 10)
      Class.new {
        include ActiveSupport::Callbacks
        define_callbacks :foo
        n.times { set_callback :foo, :before, callback }
        def run; run_callbacks :foo; end
        def self.skip(*things); skip_callback :foo, :before, *things; end
      }
    end

    def test_add_class
      calls = []
      callback = Class.new {
        define_singleton_method(:before) { |o| calls << o }
      }
      build_class(callback).new.run
      assert_equal 10, calls.length
    end

    def test_add_lambda
      calls = []
      build_class(->(o) { calls << o }).new.run
      assert_equal 10, calls.length
    end

    def test_add_symbol
      calls = []
      klass = build_class(:bar)
      klass.class_eval { define_method(:bar) { calls << klass } }
      klass.new.run
      assert_equal 1, calls.length
    end

    def test_skip_class # removes one at a time
      calls = []
      callback = Class.new {
        define_singleton_method(:before) { |o| calls << o }
      }
      klass = build_class(callback)
      9.downto(0) { |i|
        klass.skip callback
        klass.new.run
        assert_equal i, calls.length
        calls.clear
      }
    end

    def test_skip_symbol # removes all
      calls = []
      klass = build_class(:bar)
      klass.class_eval { define_method(:bar) { calls << klass } }
      klass.skip :bar
      klass.new.run
      assert_equal 0, calls.length
    end

    def test_skip_string # raises error
      calls = []
      klass = build_class(:bar)
      klass.class_eval { define_method(:bar) { calls << klass } }
      assert_raises(ArgumentError) { klass.skip "bar" }
      klass.new.run
      assert_equal 1, calls.length
    end

    def test_skip_undefined_callback # raises error
      calls = []
      klass = build_class(:bar)
      klass.class_eval { define_method(:bar) { calls << klass } }
      assert_raises(ArgumentError) { klass.skip :qux }
      klass.new.run
      assert_equal 1, calls.length
    end

    def test_skip_without_raise # removes nothing
      calls = []
      klass = build_class(:bar)
      klass.class_eval { define_method(:bar) { calls << klass } }
      klass.skip :qux, raise: false
      klass.new.run
      assert_equal 1, calls.length
    end
  end

  class NotSupportedStringConditionalTest < ActiveSupport::TestCase
    def test_string_conditional_options
      klass = Class.new(Record)

      assert_raises(ArgumentError) { klass.before_save :tweedle, if: ["true"] }
      assert_raises(ArgumentError) { klass.before_save :tweedle, if: "true" }
      assert_raises(ArgumentError) { klass.after_save :tweedle, unless: "false" }
      assert_raises(ArgumentError) { klass.skip_callback :save, :before, :tweedle, if: "true" }
      assert_raises(ArgumentError) { klass.skip_callback :save, :after, :tweedle, unless: "false" }
    end
  end

  class NotPermittedStringCallbackTest < ActiveSupport::TestCase
    def test_passing_string_callback_is_not_permitted
      klass = Class.new(Record)

      assert_raises(ArgumentError) do
        klass.before_save "tweedle"
      end
    end
  end

  class AllSaveCallbacks
    include ActiveSupport::Callbacks

    attr_reader :history
    define_callbacks :save

    def initialize
      @history = []
    end

    set_callback :save, :before, :before_save_1
    set_callback :save, :before, :before_save_2
    set_callback :save, :around, :around_save_1
    set_callback :save, :around, :around_save_2
    set_callback :save, :after, :after_save_1
    set_callback :save, :after, :after_save_2

    def before_save_1
      @history << __method__.to_s
    end

    def before_save_2
      @history <<  __method__.to_s
    end

    def around_save_1
      @history <<  __method__.to_s + "_before"
      yield
      @history <<  __method__.to_s + "_after"
    end

    def around_save_2
      @history <<  __method__.to_s + "_before"
      yield
      @history <<  __method__.to_s + "_after"
    end

    def after_save_1
      @history <<  __method__.to_s
    end

    def after_save_2
      @history <<  __method__.to_s
    end
  end

  class RunSpecificCallbackTest < ActiveSupport::TestCase
    def test_run_callbacks_only_before
      klass = AllSaveCallbacks.new
      klass.run_callbacks :save, :before
      assert_equal ["before_save_1", "before_save_2"], klass.history
    end

    def test_run_callbacks_only_around
      klass = AllSaveCallbacks.new
      klass.run_callbacks :save, :around
      assert_equal [
        "around_save_1_before",
        "around_save_2_before",
        "around_save_2_after",
        "around_save_1_after"
        ],
        klass.history
    end

    def test_run_callbacks_only_after
      klass = AllSaveCallbacks.new
      klass.run_callbacks :save, :after
      assert_equal ["after_save_2", "after_save_1"], klass.history
    end
  end
end
