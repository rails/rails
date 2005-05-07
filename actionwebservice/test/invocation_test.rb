require File.dirname(__FILE__) + '/abstract_unit'

module InvocationTest
  class API < ActionWebService::API::Base
    api_method :add,             :expects => [:int, :int], :returns => [:int]
    api_method :transmogrify,    :expects_and_returns => [:string]
    api_method :fail_with_reason
    api_method :fail_generic
    api_method :no_before
    api_method :no_after
    api_method :only_one
    api_method :only_two
  end

  class Interceptor
    attr :args

    def initialize
      @args = nil
    end

    def intercept(*args)
      @args = args
    end
  end

  InterceptorClass = Interceptor.new 

  class Service < ActionController::Base
    web_service_api API

    before_invocation :intercept_before, :except => [:no_before]
    after_invocation :intercept_after, :except => [:no_after]
    prepend_after_invocation :intercept_after_first, :except => [:no_after]
    prepend_before_invocation :intercept_only, :only => [:only_one, :only_two]
    after_invocation(:only => [:only_one]) do |*args| 
      args[0].instance_variable_set('@block_invoked', args[1])
    end
    after_invocation InterceptorClass, :only => [:only_one]

    attr_accessor :before_invoked
    attr_accessor :after_invoked
    attr_accessor :after_first_invoked
    attr_accessor :only_invoked
    attr_accessor :block_invoked
    attr_accessor :invocation_result
  
    def initialize
      @before_invoked = nil
      @after_invoked = nil
      @after_first_invoked = nil
      @only_invoked = nil
      @invocation_result = nil
      @block_invoked = nil
    end
  
    def add(a, b)
      a + b
    end
  
    def transmogrify(str)
      str.upcase
    end
    
    def fail_with_reason
    end
  
    def fail_generic
    end
  
    def no_before
      5
    end
  
    def no_after
    end
  
    def only_one
    end
  
    def only_two
    end
  
    protected
      def intercept_before(name, args)
        @before_invoked = name
        return [false, "permission denied"] if name == :fail_with_reason
        return false if name == :fail_generic
      end
  
      def intercept_after(name, args, result)
        @after_invoked = name
        @invocation_result = result
      end

      def intercept_after_first(name, args, result)
        @after_first_invoked = name
      end
  
      def intercept_only(name, args)
        raise "Interception error" unless name == :only_one || name == :only_two
        @only_invoked = name
      end
  end
end

class TC_Invocation < Test::Unit::TestCase
  include ActionWebService::Invocation

  def setup
    @service = InvocationTest::Service.new
  end

  def test_invocation
    assert(perform_invocation(:add, 5, 10) == 15)
    assert(perform_invocation(:transmogrify, "hello") == "HELLO")
    assert_raises(NoMethodError) do
      perform_invocation(:nonexistent_method_xyzzy)
    end
  end

  def test_interceptor_registration
    assert(InvocationTest::Service.before_invocation_interceptors.length == 2)
    assert(InvocationTest::Service.after_invocation_interceptors.length == 4)
    assert_equal(:intercept_only, InvocationTest::Service.before_invocation_interceptors[0])
    assert_equal(:intercept_after_first, InvocationTest::Service.after_invocation_interceptors[0])
  end

  def test_interception
    assert(@service.before_invoked.nil?)
    assert(@service.after_invoked.nil?)
    assert(@service.only_invoked.nil?)
    assert(@service.block_invoked.nil?)
    assert(@service.invocation_result.nil?)
    perform_invocation(:add, 20, 50)
    assert(@service.before_invoked == :add)
    assert(@service.after_invoked == :add)
    assert(@service.invocation_result == 70)
  end

  def test_interception_canceling
    reason = nil
    perform_invocation(:fail_with_reason){|r| reason = r}
    assert(@service.before_invoked == :fail_with_reason)
    assert(@service.after_invoked.nil?)
    assert(@service.invocation_result.nil?)
    assert(reason == "permission denied")
    reason = true
    @service.before_invoked = @service.after_invoked = @service.invocation_result = nil
    perform_invocation(:fail_generic){|r| reason = r}
    assert(@service.before_invoked == :fail_generic)
    assert(@service.after_invoked.nil?)
    assert(@service.invocation_result.nil?)
    assert(reason == true)
  end

  def test_interception_except_conditions
    perform_invocation(:no_before)
    assert(@service.before_invoked.nil?)
    assert(@service.after_first_invoked == :no_before)
    assert(@service.after_invoked == :no_before)
    assert(@service.invocation_result == 5)
    @service.before_invoked = @service.after_invoked = @service.invocation_result = nil
    perform_invocation(:no_after)
    assert(@service.before_invoked == :no_after)
    assert(@service.after_invoked.nil?)
    assert(@service.invocation_result.nil?)
  end

  def test_interception_only_conditions
    assert(@service.only_invoked.nil?)
    perform_invocation(:only_one)
    assert(@service.only_invoked == :only_one)
    assert(@service.block_invoked == :only_one)
    assert(InvocationTest::InterceptorClass.args[1] == :only_one)
    @service.only_invoked = nil
    perform_invocation(:only_two)
    assert(@service.only_invoked == :only_two)
  end

  private
    def perform_invocation(method_name, *args, &block)
      @service.perform_invocation(method_name, args, &block)
    end
end
