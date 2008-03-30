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

module TZInfo
  # The timezone index file includes TimezoneIndexDefinition which provides
  # methods used to define timezones in the index.
  module TimezoneIndexDefinition #:nodoc:
    def self.append_features(base)
      super
      base.extend(ClassMethods)
    end
    
    module ClassMethods #:nodoc:
      # Defines a timezone based on data.
      def timezone(identifier)
        @timezones = [] unless @timezones
        @data_timezones = [] unless @data_timezones
        @timezones << identifier
        @data_timezones << identifier
      end
      
      # Defines a timezone which is a link to another timezone.
      def linked_timezone(identifier)
        @timezones = [] unless @timezones
        @linked_timezones = [] unless @linked_timezones
        @timezones << identifier
        @linked_timezones << identifier
      end
      
      # Returns a frozen array containing the identifiers of all the timezones.
      # Identifiers appear in the order they were defined in the index.
      def timezones
        @timezones = [] unless @timezones
        @timezones.freeze
      end
      
      # Returns a frozen array containing the identifiers of all data timezones.
      # Identifiers appear in the order they were defined in the index.
      def data_timezones
        @data_timezones = [] unless @data_timezones
        @data_timezones.freeze
      end
      
      # Returns a frozen array containing the identifiers of all linked
      # timezones. Identifiers appear in the order they were defined in 
      # the index.
      def linked_timezones
        @linked_timezones = [] unless @linked_timezones
        @linked_timezones.freeze
      end      
    end
  end
end
