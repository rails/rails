class Array
  # Backport of Array#sample based on Marc-Andre Lafortune's http://github.com/marcandre/backports/
  # Returns a random element or +n+ random elements from the array. 
  # If the array is empty and +n+ is nil, returns <tt>nil</tt>. if +n+ is passed, returns <tt>[]</tt>.
  # 
  #   [1,2,3,4,5,6].sample    # => 4 
  #   [1,2,3,4,5,6].sample(3) # => [2, 4, 5] 
  #              [].sample    # => nil
  #              [].sample(3) # => []
  def sample(n=nil)
    return self[Kernel.rand(size)] if n.nil?
    n = n.to_int
  rescue Exception => e
    raise TypeError, "Coercion error: #{n.inspect}.to_int => Integer failed:\n(#{e.message})"
  else
    raise TypeError, "Coercion error: obj.to_int did NOT return an Integer (was #{n.class})" unless n.kind_of? Integer
    raise ArgumentError, "negative array size" if n < 0
    n = size if n > size
    result = Array.new(self)
    n.times do |i|
      r = i + Kernel.rand(size - i)
      result[i], result[r] = result[r], result[i]
    end
    result[n..size] = []
    result
  end unless method_defined? :sample
end