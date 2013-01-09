class Thread
  LOCK = Mutex.new # :nodoc:

  # Returns the value of a thread local variable that has been set. Note that
  # these are different than fiber local values.
  #
  # Thread local values are carried along with threads, and do not respect
  # fibers. For example:
  #
  #   Thread.new {
  #     Thread.current.thread_variable_set("foo", "bar") # set a thread local
  #     Thread.current["foo"] = "bar"                    # set a fiber local
  #
  #     Fiber.new {
  #       Fiber.yield [
  #         Thread.current.thread_variable_get("foo"), # get the thread local
  #         Thread.current["foo"],                     # get the fiber local
  #       ]
  #     }.resume
  #   }.join.value # => ['bar', nil]
  #
  # The value <tt>"bar"</tt> is returned for the thread local, where +nil+ is returned
  # for the fiber local. The fiber is executed in the same thread, so the
  # thread local values are available.
  def thread_variable_get(key)
    locals[key.to_sym]
  end

  # Sets a thread local with +key+ to +value+. Note that these are local to
  # threads, and not to fibers. Please see Thread#thread_variable_get for
  # more information.
  def thread_variable_set(key, value)
    locals[key.to_sym] = value
  end

  # Returns an an array of the names of the thread-local variables (as Symbols).
  #
  #    thr = Thread.new do
  #      Thread.current.thread_variable_set(:cat, 'meow')
  #      Thread.current.thread_variable_set("dog", 'woof')
  #    end
  #    thr.join               #=> #<Thread:0x401b3f10 dead>
  #    thr.thread_variables   #=> [:dog, :cat]
  #
  # Note that these are not fiber local variables. Please see Thread#thread_variable_get
  # for more details.
  def thread_variables
    locals.keys
  end

  # Returns <tt>true</tt> if the given string (or symbol) exists as a
  # thread-local variable.
  #
  #    me = Thread.current
  #    me.thread_variable_set(:oliver, "a")
  #    me.thread_variable?(:oliver)    #=> true
  #    me.thread_variable?(:stanley)   #=> false
  #
  # Note that these are not fiber local variables. Please see Thread#thread_variable_get
  # for more details.
  def thread_variable?(key)
    locals.has_key?(key.to_sym)
  end

  private

  def locals
    if defined?(@locals)
      @locals
    else
      LOCK.synchronize { @locals ||= {} }
    end
  end
end unless Thread.instance_methods.include?(:thread_variable_set)
