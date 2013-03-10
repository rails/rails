module ActiveModel

	module Validations
		class Formats
			# Common formats
      #   class Person < ActiveRecord::Base
      #     validates_format_of :email, with: Formats::EMAIL
      #   end	
      
      # Internet resources	
			EMAIL = /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i
			URI		= //i
			URL		= //i

			# Telecommunication 
			ZIP_CODE = //i
			# ...	
		end
	end
end