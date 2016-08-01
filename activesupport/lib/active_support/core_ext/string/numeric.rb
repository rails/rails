class String
	# Checks a string on an Integer value
	# 
	# 	"1".is_integer?							#=> true
	#   "1.0".is_integer?						#=> false
	#   "not_numeric".is_integer?		#=> false
	def is_integer?
		true if Integer(self) rescue false
	end

	# Checks a string on a Numeric value
	# 
	# 	"1".is_numeric?							#=> true
	#   "1.0".is_numeric?						#=> true
	#   "not_numeric".is_numeric?		#=> false
	def is_numeric?
		true if Float(self) rescue false
	end

	# Checks a string on a Float value
	# 
	# 	"1".is_float?							#=> false
	#   "1.0".is_float?						#=> true
	#   "not_numeric".is_float?		#=> false
	def is_float?
		return is_numeric? unless is_integer?
		false
	end

	# Converts a string to a Numeric values (Float, Fixnum or Bignum).
	# 
	# 	"1".to_numeric								#=> 1
	# 	"1".to_numeric.class					#=> Fixnum
	# 	"1.0".to_numeric							#=> 1.0
	# 	"1.0".to_numeric.class				#=> Float
	# 	("1" * 10).to_numeric					#=> 1111111111
	# 	("1" * 10).to_numeric.class		#=> Bignum
	# 	"not_numeric".to_numeric			#=> nil	
	def to_numeric
		return Integer(self) 	if is_integer?
		return Float(self) 		if is_float? 
	end
end