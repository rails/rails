class Class
  def hash_on(delegatee)
    define_method :eql? do |other|
      self == other
    end
    
    define_method :hash do
      @hash ||= delegatee.hash
    end
  end
end