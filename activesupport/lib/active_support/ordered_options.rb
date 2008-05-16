class OrderedOptions < ActiveSupport::OrderedHash #:nodoc:
  def []=(key, value)
    super(key.to_sym, value)
  end

  def [](key)
    super(key.to_sym)
  end

  def method_missing(name, *args)
    if name.to_s =~ /(.*)=$/
      self[$1.to_sym] = args.first
    else
      self[name]
    end
  end
end
