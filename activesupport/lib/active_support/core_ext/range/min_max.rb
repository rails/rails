class Range
  range = (1..2)
  # Overriding method only when it's included from Enumerable
  unless range.method(:min).owner == self  
    def min
      b = self.begin
      e = self.end

      if block_given?
        yield(b, e)
      else
        c = b <=> e
        
        return c > 0 ? nil : b
      end
    end
  end

  # Overriding method only when it's included from Enumerable  
  unless range.method(:max).owner == self
    def max
      b = self.begin
      e = self.end
    
      if block_given?
        yield(b, e)
      else
        c = b <=> e
        
        return c > 0 ? nil : e
      end
    end
  end
end