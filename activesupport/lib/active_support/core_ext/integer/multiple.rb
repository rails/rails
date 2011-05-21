class Integer
  # Checks whether the integer is evenly dividable by the argument.
  def multiple_of?(*numbers)
    result = numbers.inject(0) do |k,div| 
      break unless k == 0
      
      begin
        self % div
      rescue ZeroDivisionError
        0 if zero? and div.zero?
      end
    end  
    result == 0 ? true : false
  end
end