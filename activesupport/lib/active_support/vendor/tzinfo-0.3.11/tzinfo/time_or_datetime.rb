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
require 'time'
require 'tzinfo/offset_rationals'

module TZInfo
  # Used by TZInfo internally to represent either a Time, DateTime or integer
  # timestamp (seconds since 1970-01-01 00:00:00).
  class TimeOrDateTime #:nodoc:
    include Comparable
    
    # Constructs a new TimeOrDateTime. timeOrDateTime can be a Time, DateTime
    # or an integer. If using a Time or DateTime, any time zone information is 
    # ignored.
    def initialize(timeOrDateTime)
      @time = nil
      @datetime = nil
      @timestamp = nil
      
      if timeOrDateTime.is_a?(Time)
        @time = timeOrDateTime        
        @time = Time.utc(@time.year, @time.mon, @time.mday, @time.hour, @time.min, @time.sec) unless @time.zone == 'UTC'        
        @orig = @time
      elsif timeOrDateTime.is_a?(DateTime)
        @datetime = timeOrDateTime
        @datetime = @datetime.new_offset(0) unless @datetime.offset == 0
        @orig = @datetime
      else
        @timestamp = timeOrDateTime.to_i
        @orig = @timestamp
      end
    end
    
    # Returns the time as a Time.
    def to_time
      unless @time        
        if @timestamp 
          @time = Time.at(@timestamp).utc
        else
          @time = Time.utc(year, mon, mday, hour, min, sec)
        end
      end
      
      @time      
    end
    
    # Returns the time as a DateTime.
    def to_datetime
      unless @datetime
        @datetime = DateTime.new(year, mon, mday, hour, min, sec)
      end
      
      @datetime
    end
    
    # Returns the time as an integer timestamp.
    def to_i
      unless @timestamp
        @timestamp = to_time.to_i
      end
      
      @timestamp
    end
    
    # Returns the time as the original time passed to new.
    def to_orig
      @orig
    end
    
    # Returns a string representation of the TimeOrDateTime.
    def to_s
      if @orig.is_a?(Time)
        "Time: #{@orig.to_s}"
      elsif @orig.is_a?(DateTime)
        "DateTime: #{@orig.to_s}"
      else
        "Timestamp: #{@orig.to_s}"
      end
    end
    
    # Returns internal object state as a programmer-readable string.
    def inspect
      "#<#{self.class}: #{@orig.inspect}>"
    end
    
    # Returns the year.
    def year
      if @time
        @time.year
      elsif @datetime
        @datetime.year
      else
        to_time.year
      end
    end
    
    # Returns the month of the year (1..12).
    def mon
      if @time
        @time.mon
      elsif @datetime
        @datetime.mon
      else
        to_time.mon
      end
    end
    alias :month :mon
    
    # Returns the day of the month (1..n).
    def mday
      if @time
        @time.mday
      elsif @datetime
        @datetime.mday
      else
        to_time.mday
      end
    end
    alias :day :mday
    
    # Returns the hour of the day (0..23).
    def hour
      if @time
        @time.hour
      elsif @datetime
        @datetime.hour
      else
        to_time.hour
      end
    end
    
    # Returns the minute of the hour (0..59).
    def min
      if @time
        @time.min
      elsif @datetime
        @datetime.min
      else
        to_time.min
      end
    end
    
    # Returns the second of the minute (0..60). (60 for a leap second).
    def sec
      if @time
        @time.sec
      elsif @datetime
        @datetime.sec
      else
        to_time.sec
      end
    end
    
    # Compares this TimeOrDateTime with another Time, DateTime, integer
    # timestamp or TimeOrDateTime. Returns -1, 0 or +1 depending whether the 
    # receiver is less than, equal to, or greater than timeOrDateTime.
    #
    # Milliseconds and smaller units are ignored in the comparison.
    def <=>(timeOrDateTime)
      if timeOrDateTime.is_a?(TimeOrDateTime)            
        orig = timeOrDateTime.to_orig
        
        if @orig.is_a?(DateTime) || orig.is_a?(DateTime)
          # If either is a DateTime, assume it is there for a reason 
          # (i.e. for range).
          to_datetime <=> timeOrDateTime.to_datetime
        elsif orig.is_a?(Time)
          to_time <=> timeOrDateTime.to_time
        else
          to_i <=> timeOrDateTime.to_i
        end        
      elsif @orig.is_a?(DateTime) || timeOrDateTime.is_a?(DateTime)
        # If either is a DateTime, assume it is there for a reason 
        # (i.e. for range).        
        to_datetime <=> TimeOrDateTime.wrap(timeOrDateTime).to_datetime
      elsif timeOrDateTime.is_a?(Time)
        to_time <=> timeOrDateTime
      else
        to_i <=> timeOrDateTime.to_i
      end
    end
    
    # Adds a number of seconds to the TimeOrDateTime. Returns a new 
    # TimeOrDateTime, preserving what the original constructed type was.
    # If the original type is a Time and the resulting calculation goes out of
    # range for Times, then an exception will be raised by the Time class.
    def +(seconds)
      if seconds == 0
        self
      else
        if @orig.is_a?(DateTime)
          TimeOrDateTime.new(@orig + OffsetRationals.rational_for_offset(seconds))
        else
          # + defined for Time and integer timestamps
          TimeOrDateTime.new(@orig + seconds)
        end
      end
    end
    
    # Subtracts a number of seconds from the TimeOrDateTime. Returns a new 
    # TimeOrDateTime, preserving what the original constructed type was.
    # If the original type is a Time and the resulting calculation goes out of
    # range for Times, then an exception will be raised by the Time class.
    def -(seconds)
      self + (-seconds)
    end
   
    # Similar to the + operator, but for cases where adding would cause a 
    # timestamp or time to go out of the allowed range, converts to a DateTime
    # based TimeOrDateTime.
    def add_with_convert(seconds)
      if seconds == 0
        self
      else
        if @orig.is_a?(DateTime)
          TimeOrDateTime.new(@orig + OffsetRationals.rational_for_offset(seconds))
        else
          # A Time or timestamp.
          result = to_i + seconds
          
          if result < 0 || result > 2147483647
            result = TimeOrDateTime.new(to_datetime + OffsetRationals.rational_for_offset(seconds))
          else
            result = TimeOrDateTime.new(@orig + seconds)
          end
        end
      end
    end
    
    # Returns true if todt represents the same time and was originally 
    # constructed with the same type (DateTime, Time or timestamp) as this 
    # TimeOrDateTime.
    def eql?(todt)
      todt.respond_to?(:to_orig) && to_orig.eql?(todt.to_orig)      
    end
    
    # Returns a hash of this TimeOrDateTime.
    def hash
      @orig.hash
    end
    
    # If no block is given, returns a TimeOrDateTime wrapping the given 
    # timeOrDateTime. If a block is specified, a TimeOrDateTime is constructed
    # and passed to the block. The result of the block must be a TimeOrDateTime.
    # to_orig will be called on the result and the result of to_orig will be
    # returned.
    #
    # timeOrDateTime can be a Time, DateTime, integer timestamp or TimeOrDateTime.
    # If a TimeOrDateTime is passed in, no new TimeOrDateTime will be constructed,
    # the passed in value will be used.
    def self.wrap(timeOrDateTime)      
      t = timeOrDateTime.is_a?(TimeOrDateTime) ? timeOrDateTime : TimeOrDateTime.new(timeOrDateTime)        
      
      if block_given?
        t = yield t
        
        if timeOrDateTime.is_a?(TimeOrDateTime)
          t          
        elsif timeOrDateTime.is_a?(Time)
          t.to_time
        elsif timeOrDateTime.is_a?(DateTime)
          t.to_datetime
        else
          t.to_i
        end        
      else
        t
      end
    end
  end
end
