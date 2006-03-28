class OrderedHash < Array #:nodoc:
  def []=(key, value)    
    if pair = find_pair(key)
      pair.pop
      pair << value
    else
      self << [key, value]
    end
  end
  
  def [](key)
    pair = find_pair(key)
    pair ? pair.last : nil
  end

  def keys
    self.collect { |i| i.first }
  end

  private
    def find_pair(key)
      self.each { |i| return i if i.first == key }
      return false
    end
end

class OrderedOptions < OrderedHash #:nodoc:
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