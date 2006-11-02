#!/usr/bin/env ruby

#---
# Copyright 2003, 2004, 2005, 2006 by Jim Weirich (jim@weirichhouse.org).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#+++

require 'test/unit'

######################################################################
# FlexMock is a flexible mock object suitable for using with Ruby's
# Test::Unit unit test framework.  FlexMock has a simple interface
# that's easy to remember, and leaves the hard stuff to all those
# other mock object implementations.
#
# Basic Usage:
#
#   m = FlexMock.new("name")
#   m.mock_handle(:meth) { |args| assert_stuff }
#
# Simplified Usage:
#
#   m = FlexMock.new("name")
#   m.should_receive(:upcase).with("stuff").
#     returns("STUFF")
#   m.should_receive(:downcase).with(String).
#     returns { |s| s.downcase }.once
#
# With Test::Unit Integration:
#
#   class TestSomething < Test::Unit::TestCase
#     include FlexMock::TestCase
#
#     def test_something
#       m = flexmock("name")
#       m.should_receive(:hi).and_return("Hello")
#       m.hi
#     end
#   end
#
# Note: When using Test::Unit integeration, don't forget to include
# FlexMock::TestCase.  Also, if you override +teardown+, make sure you
# call +super+.
#
class FlexMock
  include Test::Unit::Assertions

  class BadInterceptionError < RuntimeError; end

  attr_reader :mock_name, :mock_groups
  attr_accessor :mock_current_order

  # Create a FlexMock object with the given name.  The name is used in
  # error messages.
  def initialize(name="unknown")
    @mock_name = name
    @expectations = Hash.new
    @allocated_order = 0
    @mock_current_order = 0
    @mock_groups = {}
    @ignore_missing = false
    @verified = false
  end
  
  # Handle all messages denoted by +sym+ by calling the given block
  # and passing any parameters to the block.  If we know exactly how
  # many calls are to be made to a particular method, we may check
  # that by passing in the number of expected calls as a second
  # paramter.
  def mock_handle(sym, expected_count=nil, &block)
    self.should_receive(sym).times(expected_count).returns(&block)
  end

  # Verify that each method that had an explicit expected count was
  # actually called that many times.
  def mock_verify
    return if @verified
    @verified = true
    mock_wrap do
      @expectations.each do |sym, handler|
        handler.mock_verify
      end
    end
  end

  # Teardown and infrastructure setup for this mock.
  def mock_teardown
  end

  # Allocation a new order number from the mock.
  def mock_allocate_order
    @auto_allocate = true
    @allocated_order += 1
  end

  # Ignore all undefined (missing) method calls.
  def should_ignore_missing
    @ignore_missing = true
  end
  alias mock_ignore_missing should_ignore_missing

  # Handle missing methods by attempting to look up a handler.
  def method_missing(sym, *args, &block)
    mock_wrap do
      if handler = @expectations[sym]
        args << block  if block_given?
        handler.call(*args)
      else
        super(sym, *args, &block)  unless @ignore_missing
      end
    end
  end

  # Save the original definition of respond_to? for use a bit later.
  alias mock_respond_to? respond_to?

  # Override the built-in respond_to? to include the mocked methods.
  def respond_to?(sym)
    super || (@expectations[sym] ? true : @ignore_missing)
  end

  # Override the built-in +method+ to include the mocked methods.
  def method(sym)
    @expectations[sym] || super
  rescue NameError => ex
    if @ignore_missing
      proc { }
    else
      raise ex
    end
  end

  # Declare that the mock object should receive a message with the
  # given name.  An expectation object for the method name is returned
  # as the result of this method.  Further expectation constraints can
  # be added by chaining to the result.
  #
  # See Expectation for a list of declarators that can be used.
  def should_receive(sym)
    @expectations[sym] ||= ExpectationDirector.new(sym)
    result = Expectation.new(self, sym)
    @expectations[sym] << result
    override_existing_method(sym) if mock_respond_to?(sym)
    result
  end

  # Override the existing definition of method +sym+ in the mock.
  # Most methods depend on the method_missing trick to be invoked.
  # However, if the method already exists, it will not call
  # method_missing.  This method defines a singleton method on the
  # mock to explicitly invoke the method_missing logic.
  def override_existing_method(sym)
    sclass.class_eval "def #{sym}(*args, &block) method_missing(:#{sym}, *args, &block) end"
  end
  private :override_existing_method
  
  # Return the singleton class of the mock object.
  def sclass
    class << self; self; end
  end
  private :sclass

  # Declare that the mock object should expect methods by providing a
  # recorder for the methods and having the user invoke the expected
  # methods in a block.  Further expectations may be applied the
  # result of the recording call.
  #
  # Example Usage:
  #
  #   mock.should_expect do |record|
  #     record.add(Integer, 4) { |a, b|
  #       a + b
  #     }.at_least.once
  #
  def should_expect
    yield Recorder.new(self)
  end

  # Return a factory object that returns this mock.  This is useful in
  # Class Interception.
  def mock_factory
    Factory.new(self)
  end

  class << self
    include Test::Unit::Assertions

    # Class method to make sure that verify is called at the end of a
    # test.  One mock object will be created for each name given to
    # the use method.  The mocks will be passed to the block as
    # arguments.  If no names are given, then a single anonymous mock
    # object will be created.
    #
    # At the end of the use block, each mock object will be verified
    # to make sure the proper number of calls have been made.
    #
    # Usage:
    #
    #   FlexMock.use("name") do |mock|    # Creates a mock named "name"
    #     mock.should_receive(:meth).
    #       returns(0).once
    #   end                               # mock is verified here
    #
    # NOTE: If you include FlexMock::TestCase into your test case
    # file, you can create mocks that will be automatically verified in
    # the test teardown by using the +flexmock+ method. 
    #
    def use(*names)
      names = ["unknown"] if names.empty?
      got_excecption = false
      mocks = names.collect { |n| new(n) }
      yield(*mocks)
    rescue Exception => ex
      got_exception = true
      raise
    ensure
      mocks.each do |mock|
        mock.mock_verify     unless got_exception
      end
    end
    
    # Class method to format a method name and argument list as a nice
    # looking string.
    def format_args(sym, args)
      if args
        "#{sym}(#{args.collect { |a| a.inspect }.join(', ')})"
      else
        "#{sym}(*args)"
      end
    end
    
    # Check will assert the block returns true.  If it doesn't, an
    # assertion failure is triggered with the given message.
    def check(msg, &block)
      assert_block(msg, &block)
    end
  end

  private

  # Wrap a block of code so the any assertion errors are wrapped so
  # that the mock name is added to the error message .
  def mock_wrap(&block)
    yield
  rescue Test::Unit::AssertionFailedError => ex
    raise Test::Unit::AssertionFailedError, 
      "in mock '#{@mock_name}': #{ex.message}",
      ex.backtrace
  end

  ####################################################################
  # A Factory object is returned from a mock_factory method call.  The
  # factory merely returns the manufactured object it is initialized
  # with.  The factory is handy to use with class interception,
  # allowing the intercepted class to return the mock object.
  #
  # If the user needs more control over the mock factory, they are
  # free to create their own.
  #
  # Typical Usage:
  #    intercept(Bar).in(Foo).with(a_mock.mack_factory)
  #
  class Factory
    def initialize(manufactured_object)
      @obj = manufactured_object
    end
    def new(*args, &block)
      @obj
    end
  end

  ####################################################################
  # The expectation director is responsible for routing calls to the
  # correct expectations for a given argument list.
  #
  class ExpectationDirector

    # Create an ExpectationDirector for a mock object.
    def initialize(sym)
      @sym = sym
      @expectations = []
      @expected_order = nil
    end

    # Invoke the expectations for a given set of arguments.
    #
    # First, look for an expectation that matches the arguements and
    # is eligible to be called.  Failing that, look for a expectation
    # that matches the arguments (at this point it will be ineligible,
    # but at least we will get a good failure message).  Finally,
    # check for expectations that don't have any argument matching
    # criteria.
    def call(*args)
      exp = @expectations.find { |e| e.match_args(args) && e.eligible? } ||
        @expectations.find { |e| e.match_args(args) } ||
        @expectations.find { |e| e.expected_args.nil? }
      FlexMock.check("no matching handler found for " +
        FlexMock.format_args(@sym, args)) { ! exp.nil? }
      exp.verify_call(*args)
    end

    # Same as call.
    def [](*args)
      call(*args)
    end

    # Append an expectation to this director.
    def <<(expectation)
      @expectations << expectation
    end

    # Do the post test verification for this directory.  Check all the
    # expectations.
    def mock_verify
      @expectations.each do |exp|
        exp.mock_verify
      end
    end
  end

  ####################################################################
  # Match any object
  class AnyMatcher
    def ===(target)
      true
    end
    def inspect
      "ANY"
    end
  end
  
  ####################################################################
  # Match only things that are equal.
  class EqualMatcher
    def initialize(obj)
      @obj = obj
    end
    def ===(target)
      @obj == target
    end
    def inspect
      "==(#{@obj.inspect})"
    end
  end
  
  ANY = AnyMatcher.new

  ####################################################################
  # Match only things where the block evaluates to true.
  class ProcMatcher
    def initialize(&block)
      @block = block
    end
    def ===(target)
      @block.call(target)
    end
    def inspect
      "on{...}"
    end
  end

  ####################################################################
  # Include this module in your test class if you wish to use the +eq+
  # and +any+ argument matching methods without a prefix.  (Otherwise
  # use <tt>FlexMock.any</tt> and <tt>FlexMock.eq(obj)</tt>.
  #
  module ArgumentTypes
    # Return an argument matcher that matches any argument.
    def any
      ANY
    end

    # Return an argument matcher that only matches things equal to
    # (==) the given object.
    def eq(obj)
      EqualMatcher.new(obj)
    end

    # Return an argument matcher that matches any object, that when
    # passed to the supplied block, will cause the block to return
    # true.
    def on(&block)
      ProcMatcher.new(&block)
    end
  end
  extend ArgumentTypes

  ####################################################################
  # Base class for all the count validators.
  #
  class CountValidator
    include Test::Unit::Assertions
    def initialize(expectation, limit)
      @exp = expectation
      @limit = limit
    end

    # If the expectation has been called +n+ times, is it still
    # eligible to be called again?  The default answer compares n to
    # the established limit.
    def eligible?(n)
      n < @limit
    end
  end

  ####################################################################
  # Validator for exact call counts.
  #
  class ExactCountValidator < CountValidator
    # Validate that the method expectation was called exactly +n+
    # times.
    def validate(n)
      assert_equal @limit, n, 
        "method '#{@exp}' called incorrect number of times"
    end
  end

  ####################################################################
  # Validator for call counts greater than or equal to a limit.
  #
  class AtLeastCountValidator < CountValidator
    # Validate the method expectation was called no more than +n+
    # times.
    def validate(n)
      assert n >= @limit,
        "Method '#{@exp}' should be called at least #{@limit} times,\n" +
        "only called #{n} times"
    end

    # If the expectation has been called +n+ times, is it still
    # eligible to be called again?  Since this validator only
    # establishes a lower limit, not an upper limit, then the answer
    # is always true.
    def eligible?(n)
      true
    end
  end

  ####################################################################
  # Validator for call counts less than or equal to a limit.
  #
  class AtMostCountValidator < CountValidator
    # Validate the method expectation was called at least +n+ times.
    def validate(n)
      assert n <= @limit,
        "Method '#{@exp}' should be called at most #{@limit} times,\n" +
        "only called #{n} times"
    end
  end

  ####################################################################
  # An Expectation is returned from each +should_receive+ message sent
  # to mock object.  Each expectation records how a message matching
  # the message name (argument to +should_receive+) and the argument
  # list (given by +with+) should behave.  Mock expectations can be
  # recorded by chaining the declaration methods defined in this
  # class.
  #
  # For example:
  #
  #   mock.should_receive(:meth).with(args).and_returns(result)
  #
  class Expectation
    include Test::Unit::Assertions

    attr_reader :expected_args, :mock, :order_number

    # Create an expectation for a method named +sym+.
    def initialize(mock, sym)
      @mock = mock
      @sym = sym
      @expected_args = nil
      @count_validators = []
      @count_validator_class = ExactCountValidator
      @actual_count = 0
      @return_value = nil
      @return_block = lambda { @return_value }
      @order_number = nil
    end

    def to_s
      FlexMock.format_args(@sym, @expected_args)
    end

    # Verify the current call with the given arguments matches the
    # expectations recorded in this object.
    def verify_call(*args)
      validate_order
      @actual_count += 1
      @return_block.call(*args)
    end

    # Is this expectation eligible to be called again?  It is eligible
    # only if all of its count validators agree that it is eligible.
    def eligible?
      @count_validators.all? { |v| v.eligible?(@actual_count) }
    end

    # Validate that the order 
    def validate_order
      return if @order_number.nil?
      FlexMock.check("method #{to_s} called out of order " +
        "(expected order #{@order_number}, was #{@mock.mock_current_order})") {
        @order_number >= @mock.mock_current_order
      }
      @mock.mock_current_order = @order_number
    end
    private :validate_order

    # Validate the correct number of calls have been made.  Called by
    # the teardown process.
    def mock_verify
      @count_validators.each do |v|
        v.validate(@actual_count)
      end
    end

    # Does the argument list match this expectation's argument
    # specification.
    def match_args(args)
      return false if @expected_args.nil?
      return false if args.size != @expected_args.size
      (0...args.size).all? { |i| match_arg(@expected_args[i], args[i]) }
    end

    # Does the expected argument match the corresponding actual value.
    def match_arg(expected, actual)
      expected === actual ||
        expected == actual ||
        ( Regexp === expected && expected === actual.to_s )
    end

    # Declare that the method should expect the given argument list.
    def with(*args)
      @expected_args = args
      self
    end

    # Declare that the method should be called with no arguments.
    def with_no_args
      with
    end

    # Declare that the method can be called with any number of
    # arguments of any type.
    def with_any_args
      @expected_args = nil
      self
    end

    # Declare that the method returns a particular value (when the
    # argument list is matched).
    #
    # * If a single value is given, it will be returned for all matching
    #   calls.
    # * If multiple values are given, each value will be returned in turn for 
    #   each successive call.  If the number of matching calls is greater
    #   than the number of values, the last value will be returned for 
    #   the extra matching calls.
    # * If a block is given, it is evaluated on each call and its 
    #   value is returned.  
    # 
    # For example:
    # 
    #  mock.should_receive(:f).returns(12)   # returns 12
    #
    #  mock.should_receive(:f).with(String). # returns an
    #    returns { |str| str.upcase }        # upcased string
    #
    # +and_return+ is an alias for +returns+.
    #
    def returns(*args, &block)
      @return_block = block_given? ? 
        block : 
        lambda { args.size == 1 ? args.first : args.shift }
      self
    end
    alias :and_return :returns  # :nodoc:

    # Declare that the method may be called any number of times.
    def zero_or_more_times
      at_least.never
    end

    # Declare that the method is called +limit+ times with the
    # declared argument list.  This may be modified by the +at_least+
    # and +at_most+ declarators.
    def times(limit)
      @count_validators << @count_validator_class.new(self, limit) unless limit.nil?
      @count_validator_class = ExactCountValidator
      self
    end

    # Declare that the method is never expected to be called with the
    # given argument list.  This may be modified by the +at_least+ and
    # +at_most+ declarators.
    def never
      times(0)
    end

    # Declare that the method is expected to be called exactly once
    # with the given argument list.  This may be modified by the
    # +at_least+ and +at_most+ declarators.
    def once
      times(1)
    end

    # Declare that the method is expected to be called exactly twice
    # with the given argument list.  This may be modified by the
    # +at_least+ and +at_most+ declarators.
    def twice
      times(2)
    end

    # Modifies the next call count declarator (+times+, +never+,
    # +once+ or +twice+) so that the declarator means the method is
    # called at least that many times.
    #
    # E.g. method f must be called at least twice:
    #
    #   mock.should_receive(:f).at_least.twice
    #
    def at_least
      @count_validator_class = AtLeastCountValidator
      self
    end

    # Modifies the next call count declarator (+times+, +never+,
    # +once+ or +twice+) so that the declarator means the method is
    # called at most that many times.
    #
    # E.g. method f must be called no more than twice
    #
    #   mock.should_receive(:f).at_most.twice
    #
    def at_most
      @count_validator_class = AtMostCountValidator
      self
    end

    # Declare that the given method must be called in order.  All
    # ordered method calls must be received in the order specified by
    # the ordering of the +should_receive+ messages.  Receiving a
    # methods out of the specified order will cause a test failure.
    #
    # If the user needs more fine control over ordering
    # (e.g. specifying that a group of messages may be received in any
    # order as long as they all come after another group of messages),
    # a _group_ _name_ may be specified in the +ordered+ calls.  All
    # messages within the same group may be received in any order.
    #
    # For example, in the following, messages +flip+ and +flop+ may be
    # received in any order (because they are in the same group), but
    # must occur strictly after +start+ but before +end+.  The message
    # +any_time+ may be received at any time because it is not
    # ordered.
    #
    #    m = FlexMock.new
    #    m.should_receive(:any_time)
    #    m.should_receive(:start).ordered
    #    m.should_receive(:flip).ordered(:flip_flop_group)
    #    m.should_receive(:flop).ordered(:flip_flop_group)
    #    m.should_receive(:end).ordered
    #
    def ordered(group_name=nil)
      if group_name.nil?
        @order_number = @mock.mock_allocate_order
      elsif (num = @mock.mock_groups[group_name])
        @order_number = num
      else
        @order_number = @mock.mock_allocate_order
        @mock.mock_groups[group_name] = @order_number
      end
      self
    end
  end

  ####################################################################
  # Translate arbitrary method calls into expectations on the given
  # mock object.
  #
  class Recorder
    include FlexMock::ArgumentTypes

    # Create a method recorder for the mock +mock+.
    def initialize(mock)
      @mock = mock
      @strict = false
    end

    # Place the record in strict mode.  While recording expectations
    # in strict mode, the following will be true.
    #
    # * All expectations will be expected in the order they were
    #   recorded.
    # * All expectations will be expected once.
    # * All arguments will be placed in exact match mode,
    #   including regular expressions and class objects.
    #
    # Strict mode is usually used when giving the recorder to a known
    # good algorithm.  Strict mode captures the exact sequence of
    # calls and validate that the code under test performs the exact
    # same sequence of calls.
    #
    # The recorder may exit strict mode via a
    # <tt>should_be_strict(false)</tt> call.  Non-strict expectations
    # may be recorded at that point, or even explicit expectations
    # (using +should_receieve+) can be specified.
    #
    def should_be_strict(is_strict=true)
      @strict = is_strict
    end

    # Is the recorder in strict mode?
    def strict?
      @strict
    end

    # Record an expectation for receiving the method +sym+ with the
    # given arguments.
    def method_missing(sym, *args, &block)
      expectation = @mock.should_receive(sym).and_return(&block)
      if @strict
        args = args.collect { |arg| eq(arg) }
        expectation.with(*args).ordered.once
      else
        expectation.with(*args)
      end
      expectation
    end
  end
  
  ####################################################################
  # Test::Unit::TestCase Integration.
  #
  # Include this module in any TestCase class in a Test::Unit test
  # suite to get integration with FlexMock.  When this module is
  # included, mocks may be created with a simple call to the
  # +flexmock+ method.  Mocks created with via the method call will
  # automatically be verified in the teardown of the test case.
  #
  # <b>Note:</b> If you define a +teardown+ method in the test case,
  # <em>dont' forget to invoke the +super+ method!</em> Failure to
  # invoke super will cause all mocks to not be verified.
  #
  module TestCase
    include ArgumentTypes

    # Teardown the test case, verifying any mocks that might have been
    # defined in this test case.
    def teardown
      super
      flexmock_teardown
    end
    
    # Do the flexmock specific teardown stuff.
    def flexmock_teardown
      @flexmock_created_mocks ||= []
      if passed?
        @flexmock_created_mocks.each do |m|
          m.mock_verify
        end
      end
    ensure
      @flexmock_created_mocks.each do |m|
        m.mock_teardown
      end
      @flexmock_interceptors ||= []
      @flexmock_interceptors.each do |i|
        i.restore
      end
    end

    # Create a FlexMock object with the given name.  Mocks created
    # with this method will be automatically verify during teardown
    # (assuming the the flexmock teardown isn't overridden).
    #
    # If a block is given, then the mock object is passed to the block and
    # may be configured in the block.
    def flexmock(name="unknown")
      mock = FlexMock.new(name)
      yield(mock) if block_given?
      flexmock_remember(mock)
      mock
    end
    
    # Stub the given object by overriding the behavior of individual methods.
    # The stub object returned will respond to the +should_receive+ 
    # method, just like normal stubs.  Singleton methods cannot be 
    # stubbed.
    #
    # Example:  Stub out DBI to return a fake db connection.
    #
    #   flexstub(DBI).should_receive(:connect).and_return {
    #     fake_db = flexmock("db connection")
    #     fake_db.should_receive(:select_all).and_return(...)
    #     fake_db
    #   }
    #
    def flexstub(obj, name=nil)
      name ||= "flexstub(#{obj.class.to_s})"
      obj.instance_eval {
        @flexmock_proxy ||= StubProxy.new(obj, FlexMock.new(name))
      }
      flexmock_remember(obj.instance_variable_get("@flexmock_proxy"))
    end
    
    # Intercept the named class in the target class for the duration
    # of the test.  Class interception is very simple-minded and has a
    # number of restrictions.  First, the intercepted class must be
    # reference in the tested class via a simple constant name
    # (e.g. no scoped names using "::") that is not directly defined
    # in the class itself.  After the test, a proxy class constant
    # will be left behind that will forward all calls to the original
    # class.
    #
    # Usage:
    #   intercept(SomeClass).in(ClassBeingTested).with(MockClass)
    #   intercept(SomeClass).with(MockClass).in(ClassBeingTested)
    #
    def intercept(intercepted_class)
      result = Interception.new(intercepted_class)
      @flexmock_interceptors ||= []
      @flexmock_interceptors << result
      result
    end
    
    private
    
    def flexmock_remember(mocking_object)
      @flexmock_created_mocks ||= []
      @flexmock_created_mocks << mocking_object
      mocking_object
    end
  end

  ####################################################################
  # A Class Interception defines a constant in the target class to be
  # a proxy that points to a replacement class for the duration of a
  # test.  When an interception is restored, the proxy will point to
  # the original intercepted class.
  #
  class Interception
    # Create an interception object with the class to intercepted.
    def initialize(intercepted_class)
      @intercepted = nil
      @target  = nil
      @replacement = nil
      @proxy = nil
      intercept(intercepted_class)
      update
    end

    # Intercept this class in the class to be tested.
    def intercept(intercepted_class)
      @intercepted = intercepted_class
      update
      self
    end
    
    # Define the class number test that will receive the
    # interceptioned definition.
    def in(target_class)
      @target = target_class
      update
      self
    end

    # Define the replacement class.  This is normally a proxy or a
    # stub.
    def with(replacement_class)
      @replacement = replacement_class
      update
      self
    end

    # Restore the original class.  The proxy remains in place however.
    def restore
      @proxy.proxied_class = @restore_class if @proxy
    end
    
    private
    
    # Update the interception if the definition is complete.
    def update
      if complete?
        do_interception
      end
    end
      
    # Is the interception definition complete.  In other words, are
    # all three actors defined?
    def complete?
      @intercepted && @target && @replacement
    end

    # Implement interception on the classes defined.
    def do_interception
      @target_class = coerce_class(@target, "target")
      @replacement_class = coerce_class(@replacement, "replacement")
      case @intercepted
      when String, Symbol
        @intercepted_name = @intercepted.to_s
      when Class
        @intercepted_name = @intercepted.name
      end
      @intercepted_class = coerce_class(@intercepted, "intercepted")
      current_class = @target_class.const_get(@intercepted_name)
      if ClassProxy === current_class
        @proxy = current_class
        @restore_class = @proxy.proxied_class
        @proxy.proxied_class = @replacement_class
      else
        @proxy = ClassProxy.new(@replacement_class)
        @restore_class = current_class
        @target_class.const_set(@intercepted_name, @proxy)
      end
    end

    # Coerce a class object, string to symbol to be the class object.
    def coerce_class(klass, where)
      case klass
      when String, Symbol
        lookup_const(klass.to_s, where)
      else
        klass
      end
    end

    def lookup_const(name, where, target=Object)
      begin
        target.const_get(name)
      rescue NameError
        raise BadInterceptionError, "in #{where} class #{name}"
      end
    end
  end

  ####################################################################
  # Class Proxy for class interception.  Forward all method calls to
  # whatever is the proxied_class.
  #
  class ClassProxy
    attr_accessor :proxied_class
    def initialize(default_class)
      @proxied_class = default_class
    end
    def method_missing(sym, *args, &block)
      @proxied_class.__send__(sym, *args, &block)
    end
  end
  
  ####################################################################
  # StubProxy is used to mate the mock framework to an existing
  # object.  The object is "enhanced" with a reference to a mock
  # object (stored in <tt>@flexmock_mock</tt>).  When the 
  # +should_receive+ method is sent to the proxy, it overrides the 
  # existing object's method by creating  singleton method that 
  # forwards to the mock.  When testing is complete, StubProxy
  # will erase the mocking infrastructure from the object being 
  # stubbed (e.g. remove instance variables and mock singleton 
  # methods).
  #
  class StubProxy
    attr_reader :mock
    
    def initialize(obj, mock)
      @obj = obj
      @mock = mock
      @method_definitions = {}
      @methods_proxied = []
    end
    
    # Stub out the given method in the existing object and then let the 
    # mock object handle should_receive.
    def should_receive(method_name)
      method_name = method_name.to_sym
      unless @methods_proxied.include?(method_name)
        hide_existing_method(method_name)
        @methods_proxied << method_name
      end
      @mock.should_receive(method_name)
    end
    
    # Verify that the mock has been properly called.  After verification, 
    # detach the mocking infrastructure from the existing object.
    def mock_verify
      @mock.mock_verify
    end

    # Remove all traces of the mocking framework from the existing object.
    def mock_teardown
      if ! detached?
        @methods_proxied.each do |method_name|
          remove_current_method(method_name)
          restore_original_definition(method_name)
        end
        @obj.instance_variable_set("@flexmock_proxy", nil)
        @obj = nil
      end
    end

    private

    # The singleton class of the object.
    def sclass
      class << @obj; self; end
    end

    # Is the current method a singleton method in the object we are
    # mocking?
    def singleton?(method_name)
      @obj.methods(false).include?(method_name.to_s)
    end

    # Hide the existing method definition with a singleton defintion
    # that proxies to our mock object.  If the current definition is a
    # singleton, we need to record the definition and remove it before
    # creating our own singleton method.  If the current definition is
    # not a singleton, all we need to do is override it with our own
    # singleton.
    def hide_existing_method(method_name)
      if singleton?(method_name)
        @method_definitions[method_name] = @obj.method(method_name)
        remove_current_method(method_name)
      end
      define_proxy_method(method_name)
    end

    # Define a proxy method that forwards to our mock object.  The
    # proxy method is defined as a singleton method on the object
    # being mocked.
    def define_proxy_method(method_name)
      sclass.class_eval %{
        def #{method_name}(*args, &block)
          @flexmock_proxy.mock.#{method_name}(*args, &block)
        end  
      }
    end

    # Restore the original singleton defintion for method_name that
    # was saved earlier.
    def restore_original_definition(method_name)
      method_def = @method_definitions[method_name]
      if method_def
        sclass.class_eval {
          define_method(method_name, &method_def)
        }
      end
    end

    # Remove the current method if it is a singleton method of the
    # object being mocked.
    def remove_current_method(method_name)
      sclass.class_eval { remove_method(method_name) }
    end

    # Have we been detached from the existing object?
    def detached?
      @obj.nil?
    end
    
  end
end
