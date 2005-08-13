class Module
  def const_during(constant, value)
    if const_defined?(constant)
      overridden = true
      saved = const_get(constant)
      remove_const(constant)
    end

    const_set(constant, value)
    yield
  ensure
    if overridden
      remove_const(constant)
      const_set(constant, saved)
    end
  end
end

class MockLogger
  def info(msg,pfx=nil) end
  def debug(msg,pfx=nil) end
end

class MockConfiguration < Hash
  def logger
    @logger ||= MockLogger.new
  end

  def method_missing(sym, *args)
    if args.length == 0
      self[sym]
    else
      super
    end
  end
end
