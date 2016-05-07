class Array                                                                     
  # Returns an array of all elements that match pattern                         
  # the original type of the element is preserved
  #
  #   [:ham, :cheese, 'Bob Saget'].match_all(/e/) #=> [:cheese, 'Bob Saget']
  #
  def match_all(pattern)                                                        
    self.inject([]) do |matches, element|                                       
      element.to_s.match(pattern) ? matches << element : matches                
    end                                                                         
  end                                                                           
end
