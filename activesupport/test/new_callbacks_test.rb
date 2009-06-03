# require 'abstract_unit'
require 'test/unit'
$:.unshift "#{File.dirname(__FILE__)}/../lib"
require 'active_support'

module NewCallbacksTest
  class Record
    include ActiveSupport::NewCallbacks

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

      def callback_string(callback_method)
        "history << [#{callback_method.to_sym.inspect}, :string]"
      end

      def callback_proc(callback_method)
        Proc.new { |model| model.history << [callback_method, :proc] }
      end

      def callback_object(callback_method)
        klass = Class.new
        klass.send(:define_method, callback_method) do |model|
          model.history << [:"#{callback_method}_save", :object]
        end
        klass.new
      end
    end

    def history
      @history ||= []
    end
  end

  class Person < Record
    [:before_save, :after_save].each do |callback_method|
      callback_method_sym = callback_method.to_sym
      send(callback_method, callback_symbol(callback_method_sym))
      send(callback_method, callback_string(callback_method_sym))
      send(callback_method, callback_proc(callback_method_sym))
      send(callback_method, callback_object(callback_method_sym.to_s.gsub(/_save/, '')))
      send(callback_method) { |model| model.history << [callback_method_sym, :block] }
    end

    def save
      _run_save_callbacks {}
    end
  end

  class PersonSkipper < Person
    skip_callback :save, :before, :before_save_method, :if => :yes
    skip_callback :save, :after, :before_save_method, :unless => :yes
    skip_callback :save, :after, :before_save_method, :if => :no
    skip_callback :save, :before, :before_save_method, :unless => :no
    def yes; true; end
    def no; false; end
  end

  class ParentController
    include ActiveSupport::NewCallbacks

    define_callbacks :dispatch
    
    set_callback :dispatch, :before, :log, :per_key => {:unless => proc {|c| c.action_name == :index || c.action_name == :show }}
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
      _run_dispatch_callbacks(action_name) {
        @logger << "Done"
      }
      self
    end
  end

  class Child < ParentController
    skip_callback :dispatch, :before, :log, :per_key => {:if => proc {|c| c.action_name == :update} }
    skip_callback :dispatch, :after, :log2
  end

  class OneTimeCompile < Record
    @@starts_true, @@starts_false = true, false
  
    def initialize
      super
    end
  
    before_save Proc.new {|r| r.history << [:before_save, :starts_true, :if] }, :per_key => {:if => :starts_true}
    before_save Proc.new {|r| r.history << [:before_save, :starts_false, :if] }, :per_key => {:if => :starts_false}
    before_save Proc.new {|r| r.history << [:before_save, :starts_true, :unless] }, :per_key => {:unless => :starts_true}
    before_save Proc.new {|r| r.history << [:before_save, :starts_false, :unless] }, :per_key => {:unless => :starts_false}
  
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
      _run_save_callbacks(:action) {}
    end
  end

  class OneTimeCompileTest < Test::Unit::TestCase
    def test_optimized_first_compile
      around = OneTimeCompile.new
      around.save
      assert_equal [
        [:before_save, :starts_true, :if],
        [:before_save, :starts_true, :unless]
      ], around.history
    end
  end

  class ConditionalPerson < Record
    # proc
    before_save Proc.new { |r| r.history << [:before_save, :proc] }, :if => Proc.new { |r| true }
    before_save Proc.new { |r| r.history << "b00m" }, :if => Proc.new { |r| false }
    before_save Proc.new { |r| r.history << [:before_save, :proc] }, :unless => Proc.new { |r| false }
    before_save Proc.new { |r| r.history << "b00m" }, :unless => Proc.new { |r| true }
    # symbol
    before_save Proc.new { |r| r.history << [:before_save, :symbol] }, :if => :yes
    before_save Proc.new { |r| r.history << "b00m" }, :if => :no
    before_save Proc.new { |r| r.history << [:before_save, :symbol] }, :unless => :no
    before_save Proc.new { |r| r.history << "b00m" }, :unless => :yes
    # string
    before_save Proc.new { |r| r.history << [:before_save, :string] }, :if => 'yes'
    before_save Proc.new { |r| r.history << "b00m" }, :if => 'no'
    before_save Proc.new { |r| r.history << [:before_save, :string] }, :unless => 'no'
    before_save Proc.new { |r| r.history << "b00m" }, :unless => 'yes'
    # Combined if and unless
    before_save Proc.new { |r| r.history << [:before_save, :combined_symbol] }, :if => :yes, :unless => :no
    before_save Proc.new { |r| r.history << "b00m" }, :if => :yes, :unless => :yes

    def yes; true; end
    def other_yes; true; end
    def no; false; end
    def other_no; false; end

    def save
      _run_save_callbacks {}
    end
  end

  class MySuper
    include ActiveSupport::NewCallbacks
    define_callbacks :save
  end

  class AroundPerson < MySuper
    attr_reader :history
  
    set_callback :save, :before, :nope,           :if =>     :no
    set_callback :save, :before, :nope,           :unless => :yes
    set_callback :save, :after,  :tweedle
    set_callback :save, :before, "tweedle_dee"
    set_callback :save, :before, proc {|m| m.history << "yup" }
    set_callback :save, :before, :nope,           :if =>     proc { false }
    set_callback :save, :before, :nope,           :unless => proc { true }
    set_callback :save, :before, :yup,            :if =>     proc { true }
    set_callback :save, :before, :yup,            :unless => proc { false }
    set_callback :save, :around, :tweedle_dum
    set_callback :save, :around, :w0tyes,         :if =>     :yes
    set_callback :save, :around, :w0tno,          :if =>     :no
    set_callback :save, :around, :tweedle_deedle
  
    def no; false; end
    def yes; true; end
  
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
  
    def tweedle_dee
      @history << "tweedle dee"
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
  
    def initialize
      @history = []
    end
  
    def save
      _run_save_callbacks do
        @history << "running"
      end
    end
  end

  class HyphenatedCallbacks
    include ActiveSupport::NewCallbacks
    define_callbacks :save
    attr_reader :stuff
    
    set_callback :save, :before, :omg, :per_key => {:if => :yes}
    
    def yes() true end
      
    def omg
      @stuff = "OMG"
    end
    
    def save
      _run_save_callbacks("hyphen-ated") do
        @stuff
      end
    end
  end

  class AroundCallbacksTest < Test::Unit::TestCase
    def test_save_around
      around = AroundPerson.new
      around.save
      assert_equal [
        "tweedle dee",
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

  class SkipCallbacksTest < Test::Unit::TestCase
    def test_skip_person
      person = PersonSkipper.new
      assert_equal [], person.history
      person.save
      assert_equal [
        [:before_save, :string],
        [:before_save, :proc],
        [:before_save, :object],
        [:before_save, :block],
        [:after_save, :block],
        [:after_save, :object],
        [:after_save, :proc],
        [:after_save, :string],
        [:after_save, :symbol]
      ], person.history
    end
  end

  class CallbacksTest < Test::Unit::TestCase
    def test_save_person
      person = Person.new
      assert_equal [], person.history
      person.save
      assert_equal [
        [:before_save, :symbol],
        [:before_save, :string],
        [:before_save, :proc],
        [:before_save, :object],
        [:before_save, :block],
        [:after_save, :block],
        [:after_save, :object],
        [:after_save, :proc],
        [:after_save, :string],
        [:after_save, :symbol]
      ], person.history
    end
  end

  class ConditionalCallbackTest < Test::Unit::TestCase
    def test_save_conditional_person
      person = ConditionalPerson.new
      person.save
      assert_equal [
        [:before_save, :proc],
        [:before_save, :proc],
        [:before_save, :symbol],
        [:before_save, :symbol],
        [:before_save, :string],
        [:before_save, :string],
        [:before_save, :combined_symbol],
      ], person.history
    end
  end

  class CallbackTerminator
    include ActiveSupport::NewCallbacks
  
    define_callbacks :save, "result == :halt"
  
    set_callback :save, :before, :first
    set_callback :save, :before, :second
    set_callback :save, :around, :around_it  
    set_callback :save, :before, :third
    set_callback :save, :after, :first
    set_callback :save, :around, :around_it
    set_callback :save, :after, :second
    set_callback :save, :around, :around_it
    set_callback :save, :after, :third

  
    attr_reader :history, :saved
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
      _run_save_callbacks do
        @saved = true
      end
    end
  end

  class CallbackObject
    def before(caller)
      caller.record << "before"
    end
    
    def around(caller)
      caller.record << "around before"
      yield
      caller.record << "around after"
    end
  end

  class UsingObjectBefore
    include ActiveSupport::NewCallbacks
    
    define_callbacks :save
    set_callback :save, :before, CallbackObject.new
    
    attr_accessor :record
    def initialize
      @record = []
    end
    
    def save
      _run_save_callbacks do
        @record << "yielded"
      end
    end 
  end

  class UsingObjectAround
    include ActiveSupport::NewCallbacks
    
    define_callbacks :save
    set_callback :save, :around, CallbackObject.new
    
    attr_accessor :record
    def initialize
      @record = []
    end
    
    def save
      _run_save_callbacks do
        @record << "yielded"
      end
    end 
  end
  
  class UsingObjectTest < Test::Unit::TestCase
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
  end

  class CallbackTerminatorTest < Test::Unit::TestCase
    def test_termination
      terminator = CallbackTerminator.new
      terminator.save
      assert_equal ["first", "second", "third", "second", "first"], terminator.history
    end
    
    def test_block_never_called_if_terminated
      obj = CallbackTerminator.new
      obj.save
      assert !obj.saved
    end    
  end
  
  class HyphenatedKeyTest < Test::Unit::TestCase
    def test_save
      obj = HyphenatedCallbacks.new
      obj.save
      assert_equal obj.stuff, "OMG"
    end    
  end  
end
