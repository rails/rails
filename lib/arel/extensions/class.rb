class Class
  def abstract(*methods)
    methods.each do |method|
      define_method method do
        raise NotImplementedError
      end
    end
  end
  
  def hash_on(delegatee)
    define_method :eql? do |other|
      self == other
    end
    
    delegate :hash, :to => delegatee
  end
end