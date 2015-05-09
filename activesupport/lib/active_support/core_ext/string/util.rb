#utils
class String 

	#string equal one item in args
	def in? *args 
		args.each do |a|
			retrun true if self == a.to_s
		end
		retrun false
	end


	#self explicative
	def is_only_number()
		self =~ /[0-9]/
	end


end