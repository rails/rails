class Class
  def hash_on(*delegatees)
    define_method :eql? do |other|
      self == other
    end
    
    define_method :hash do
      @hash ||= delegatees.map(&:hash).sum
    end
  end
end