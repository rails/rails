#--
# Copyright (c) 2006 Philip Ross
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#++

require 'tzinfo/data_timezone_info'
require 'tzinfo/linked_timezone_info'

module TZInfo
  
  # TimezoneDefinition is included into Timezone definition modules.
  # TimezoneDefinition provides the methods for defining timezones.
  module TimezoneDefinition #:nodoc:
    # Add class methods to the includee.
    def self.append_features(base)
      super
      base.extend(ClassMethods)
    end
    
    # Class methods for inclusion.
    module ClassMethods #:nodoc:
      # Returns and yields a DataTimezoneInfo object to define a timezone.
      def timezone(identifier)
        yield @timezone = DataTimezoneInfo.new(identifier)
      end
      
      # Defines a linked timezone.
      def linked_timezone(identifier, link_to_identifier)
        @timezone = LinkedTimezoneInfo.new(identifier, link_to_identifier)
      end
      
      # Returns the last TimezoneInfo to be defined with timezone or 
      # linked_timezone.
      def get
        @timezone
      end
    end
  end
end
