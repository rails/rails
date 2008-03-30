#--
# Copyright (c) 2005-2006 Philip Ross
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

require 'tzinfo/timezone'

module TZInfo

  # A proxy class representing a timezone with a given identifier. TimezoneProxy
  # inherits from Timezone and can be treated like any Timezone loaded with
  # Timezone.get.
  #
  # The first time an attempt is made to access the data for the timezone, the 
  # real Timezone is loaded. If the proxy's identifier was not valid, then an 
  # exception will be raised at this point.  
  class TimezoneProxy < Timezone
    # Construct a new TimezoneProxy for the given identifier. The identifier
    # is not checked when constructing the proxy. It will be validated on the
    # when the real Timezone is loaded.
    def self.new(identifier)
      # Need to override new to undo the behaviour introduced in Timezone#new.
      tzp = super()
      tzp.send(:setup, identifier)
      tzp
    end
        
    # The identifier of the timezone, e.g. "Europe/Paris".
    def identifier
      @real_timezone ? @real_timezone.identifier : @identifier
    end
    
    # Returns the TimezonePeriod for the given UTC time. utc can either be
    # a DateTime, Time or integer timestamp (Time.to_i). Any timezone 
    # information in utc is ignored (it is treated as a UTC time).        
    def period_for_utc(utc)            
      real_timezone.period_for_utc(utc)            
    end
    
    # Returns the set of TimezonePeriod instances that are valid for the given
    # local time as an array. If you just want a single period, use 
    # period_for_local instead and specify how abiguities should be resolved.
    # Returns an empty array if no periods are found for the given time.
    def periods_for_local(local)
      real_timezone.periods_for_local(local)
    end
    
    # Dumps this TimezoneProxy for marshalling.
    def _dump(limit)
      identifier
    end
    
    # Loads a marshalled TimezoneProxy.
    def self._load(data)
      TimezoneProxy.new(data)
    end
    
    private
      def setup(identifier)
        @identifier = identifier
        @real_timezone = nil
      end  
    
      def real_timezone
        @real_timezone ||= Timezone.get(@identifier)
      end     
  end 
end
