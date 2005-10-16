begin
  require 'simplecc'
rescue LoadError
  # to satisfy rdoc
  class Continuation #:nodoc:
  end
  def Continuation.create(*args, &block) # :nodoc:
    cc = nil; result = callcc {|c| cc = c; block.call(cc) if block and args.empty?}
    result ||= args
    return *[cc, *result]
  end
end

class Binding; end # for RDoc
# This method returns the binding of the method that called your
# method. It will raise an Exception when you're not inside a method.
#
# It's used like this:
#   def inc_counter(amount = 1)
#     Binding.of_caller do |binding|
#       # Create a lambda that will increase the variable 'counter'
#       # in the caller of this method when called.
#       inc = eval("lambda { |arg| counter += arg }", binding)
#       # We can refer to amount from inside this block safely.
#       inc.call(amount)
#     end
#     # No other statements can go here. Put them inside the block.
#   end
#   counter = 0
#   2.times { inc_counter }
#   counter # => 2
#
# Binding.of_caller must be the last statement in the method.
# This means that you will have to put everything you want to
# do after the call to Binding.of_caller into the block of it.
# This should be no problem however, because Ruby has closures.
# If you don't do this an Exception will be raised. Because of
# the way that Binding.of_caller is implemented it has to be
# done this way.
def Binding.of_caller(&block)
  old_critical = Thread.critical
  Thread.critical = true
  count = 0
  cc, result, error, extra_data = Continuation.create(nil, nil)
  error.call if error

  tracer = lambda do |*args|
    type, context, extra_data = args[0], args[4], args
    if type == "return"
      count += 1
      # First this method and then calling one will return --
      # the trace event of the second event gets the context
      # of the method which called the method that called this
      # method.
      if count == 2
        # It would be nice if we could restore the trace_func
        # that was set before we swapped in our own one, but
        # this is impossible without overloading set_trace_func
        # in current Ruby.
        set_trace_func(nil)
        cc.call(eval("binding", context), nil, extra_data)
      end
    elsif type == "line" then
      nil
    elsif type == "c-return" and extra_data[3] == :set_trace_func then
      nil
    else
      set_trace_func(nil)
      error_msg = "Binding.of_caller used in non-method context or " +
        "trailing statements of method using it aren't in the block."
      cc.call(nil, lambda { raise(ArgumentError, error_msg) }, nil)
    end
  end

  unless result
    set_trace_func(tracer)
    return nil
  else
    Thread.critical = old_critical
    case block.arity
      when 1 then yield(result)
      else yield(result, extra_data)        
    end
  end
end
