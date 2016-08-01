#compare 
class Numeric

	def positive?
		self > 0.0
	end

	def negative?
		self < 0.0
	end

	def major? value
		self > value
	end

	def minor? value
		self < value
	end

	def equal? value
		self == vaule
	end

end