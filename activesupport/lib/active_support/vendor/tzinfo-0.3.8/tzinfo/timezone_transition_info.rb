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

require 'date'
require 'tzinfo/time_or_datetime'

module TZInfo
  # Represents an offset defined in a Timezone data file.
  class TimezoneTransitionInfo #:nodoc:
    # The offset this transition changes to (a TimezoneOffsetInfo instance).
    attr_reader :offset
    
    # The offset this transition changes from (a TimezoneOffsetInfo instance).
    attr_reader :previous_offset
    
    # The numerator of the DateTime if the transition time is defined as a 
    # DateTime, otherwise the transition time as a timestamp.
    attr_reader :numerator_or_time
    protected :numerator_or_time
    
    # Either the denominotor of the DateTime if the transition time is defined
    # as a DateTime, otherwise nil. 
    attr_reader :denominator
    protected :denominator
    
    # Creates a new TimezoneTransitionInfo with the given offset, 
    # previous_offset (both TimezoneOffsetInfo instances) and UTC time. 
    # if denominator is nil, numerator_or_time is treated as a number of 
    # seconds since the epoch. If denominator is specified numerator_or_time
    # and denominator are used to create a DateTime as follows:
    # 
    #  DateTime.new!(Rational.new!(numerator_or_time, denominator), 0, Date::ITALY)
    #
    # For performance reasons, the numerator and denominator must be specified
    # in their lowest form.
    def initialize(offset, previous_offset, numerator_or_time, denominator = nil)
      @offset = offset
      @previous_offset = previous_offset
      @numerator_or_time = numerator_or_time
      @denominator = denominator
      
      @at = nil
      @local_end = nil
      @local_start = nil
    end
    
    # A TimeOrDateTime instance representing the UTC time when this transition
    # occurs.
    def at
      unless @at
        unless @denominator 
          @at = TimeOrDateTime.new(@numerator_or_time)
        else
          r = Rational.new!(@numerator_or_time, @denominator)
          
          # Ruby 1.8.6 introduced new! and deprecated new0.
          # Ruby 1.9.0 removed new0.
          # We still need to support new0 for older versions of Ruby.
          if DateTime.respond_to? :new!
            dt = DateTime.new!(r, 0, Date::ITALY)
          else
            dt = DateTime.new0(r, 0, Date::ITALY)
          end
          
          @at = TimeOrDateTime.new(dt)
        end
      end
      
      @at
    end
    
    # A TimeOrDateTime instance representing the local time when this transition
    # causes the previous observance to end (calculated from at using 
    # previous_offset).
    def local_end
      @local_end = at.add_with_convert(@previous_offset.utc_total_offset) unless @local_end      
      @local_end
    end
    
    # A TimeOrDateTime instance representing the local time when this transition
    # causes the next observance to start (calculated from at using offset).
    def local_start
      @local_start = at.add_with_convert(@offset.utc_total_offset) unless @local_start
      @local_start
    end
    
    # Returns true if this TimezoneTransitionInfo is equal to the given
    # TimezoneTransitionInfo. Two TimezoneTransitionInfo instances are 
    # considered to be equal by == if offset, previous_offset and at are all 
    # equal.
    def ==(tti)
      tti.respond_to?(:offset) && tti.respond_to?(:previous_offset) && tti.respond_to?(:at) &&
        offset == tti.offset && previous_offset == tti.previous_offset && at == tti.at
    end
    
    # Returns true if this TimezoneTransitionInfo is equal to the given
    # TimezoneTransitionInfo. Two TimezoneTransitionInfo instances are 
    # considered to be equal by eql? if offset, previous_offset, 
    # numerator_or_time and denominator are all equal. This is stronger than ==,
    # which just requires the at times to be equal regardless of how they were
    # originally specified.
    def eql?(tti)
      tti.respond_to?(:offset) && tti.respond_to?(:previous_offset) &&
        tti.respond_to?(:numerator_or_time) && tti.respond_to?(:denominator) &&
        offset == tti.offset && previous_offset == tti.previous_offset &&
        numerator_or_time == tti.numerator_or_time && denominator == tti.denominator        
    end
    
    # Returns a hash of this TimezoneTransitionInfo instance.
    def hash
      @offset.hash ^ @previous_offset.hash ^ @numerator_or_time.hash ^ @denominator.hash
    end
    
    # Returns internal object state as a programmer-readable string.
    def inspect
      "#<#{self.class}: #{at.inspect},#{@offset.inspect}>"      
    end
  end
end
