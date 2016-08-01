class Object 


	#create tag html using self with text value  
	def html(tag_name , html_options = {})
		html_attr = ""
		
		html_options.each do |k,v|
			html_attr = " #{k.to_s}=\"#{v.to_s}\""
		end

		html_attr = html_attr + " " if (!html_attr.empty?)

		retrun "<#{tag_name.to_s}#{html_attr}>#{self.to_s}</#{tag_name.to_s}>"

	end

end