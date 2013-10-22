module ActiveSupport
  # <tt>ActiveSupport::ConditionalOptions</tt> can be used to evaluate truthiness of <tt>:if</tt>
  # and <tt>:unless</tt> keys in a Ruby Hash using either <tt>pass?</tt> or <tt>fail?</tt>
  # methods.
  #
  #   ActiveSupport::ConditionalOptions.new(:if => true).pass? # true
  #   ActiveSupport::ConditionalOptions.new(:if => false).fail? # true
  #
  #   ActiveSupport::ConditionalOptions.new(:unless => false).pass? # true
  #   ActiveSupport::ConditionalOptions.new(:unless => true).fail? # true
  #
  # Keys can be boolean values or expressions, and procs, the later passing an optional value
  # to the proc argument when declared.
  #
  #   ActiveSupport::ConditionalOptions.new(:if => 'foo' != 'bar').pass? # true
  #   ActiveSupport::ConditionalOptions.new(:if => lambda { 'foo' != 'bar' }).pass? # true
  #   ActiveSupport::ConditionalOptions.new(:if => lambda {|foo| foo != 'bar' }).pass?('foo') # true
  #
  # By default, conditional options will always pass when neither key is given.
  #
  #   ActiveSupport::ConditionalOptions.new.pass? # true
  #   ActiveSupport::ConditionalOptions.new.fail? # false
  class ConditionalOptions

    attr_reader :if_condition, :unless_condition

    def initialize(options = {})
      @if_condition = options.has_key?(:if) ? (!options[:if].nil? ? options[:if] : false) : true
      @unless_condition = options[:unless]
    end

    def pass?(value = nil)
      return false unless evaluate(self.if_condition, value, true)
      return false if evaluate(self.unless_condition, value, false)

      true
    end

    def fail?(value = nil)
      !pass?(value)
    end

    private

    def evaluate(condition, value, default)
      case condition
        when TrueClass, FalseClass
          condition
        when Proc
          condition.arity == 0 ? condition.call : condition.call(value)
        else
          default
      end
    end
  end
end
