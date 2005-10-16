class OrderedOptions < Array #:nodoc:
  def []=(key, value)
    key = key.to_sym
    
    if pair = find_pair(key)
      pair.pop
      pair << value
    else
      self << [key, value]
    end
  end
  
  def [](key)
    pair = find_pair(key.to_sym)
    pair ? pair.last : nil
  end

  def method_missing(name, *args)
    if name.to_s =~ /(.*)=$/
      self[$1.to_sym] = args.first
    else
      self[name]
    end
  end

  private
    def find_pair(key)
      self.each { |i| return i if i.first == key }
      return false
    end
end