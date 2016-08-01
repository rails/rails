class Object
  # Returns +false+ is this object matches any of the arguments passed in. Object
  # comparisons are made the same way as in +case+ statementes. Otherwise it 
  # returns +true+.
  #
  # +avoids?+ always expects several arguments. If an array is passed in as an
  # argument, it is treated as an array; it is *not* flattened to test this
  # object against the individual members of the array. This is the case even
  # if only a single array provided.
  #
  # Use a splat to pass in an array when you are trying to test a single 
  # list of conditions to avoid.
  #
  # ==== Examples
  #
  # weak_passwords = ['qwerty', /passwo?r?d/, /^123\d{0,3}/, /.{0,4}/]
  #
  # user.password = '$tr0ng_Pas$word?'
  # user.password.avoids?(*weak_passwords)              # => true
  # user.password = '1234'
  # user.password.avoids?(*weak_passwords)              # => false
  #
  # some_array = [1,2,3,4]
  #
  # some_array.avoids?([1,2,3,4])                       # => false
  # some_array.avoids?(1,2,3,4)                         # => true
  # some_array.avoids?(*[1,2,3,4])                      # => true
  def avoids?(*args)
    for a in args do
      case self
        when a then return false
      end
    end
 
    return true
  end
end
