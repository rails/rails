class Class
  def hash_on(delegatee)
    define_method :eql? do |other|
      self == other
    end
    
    delegate :hash, :to => delegatee
  end
end