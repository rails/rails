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
  # Represents an offset defined in a Timezone data file.
  class TimezoneOffsetInfo #:nodoc:
    # The base offset of the timezone from UTC in seconds.
    attr_reader :utc_offset
    
    # The offset from standard time for the zone in seconds (i.e. non-zero if 
    # daylight savings is being observed).
    attr_reader :std_offset
    
    # The total offset of this observance from UTC in seconds 
    # (utc_offset + std_offset).
    attr_reader :utc_total_offset
    
    # The abbreviation that identifies this observance, e.g. "GMT" 
    # (Greenwich Mean Time) or "BST" (British Summer Time) for "Europe/London". The returned identifier is a 
    # symbol.
    attr_reader :abbreviation
    
    # Constructs a new TimezoneOffsetInfo. utc_offset and std_offset are
    # specified in seconds.
    def initialize(utc_offset, std_offset, abbreviation)
      @utc_offset = utc_offset
      @std_offset = std_offset      
      @abbreviation = abbreviation
      
      @utc_total_offset = @utc_offset + @std_offset
    end
    
    # True if std_offset is non-zero.
    def dst?
      @std_offset != 0
    end
    
    # Converts a UTC DateTime to local time based on the offset of this period.
    def to_local(utc)
      TimeOrDateTime.wrap(utc) {|wrapped|
        wrapped + @utc_total_offset
      }
    end
    
    # Converts a local DateTime to UTC based on the offset of this period.
    def to_utc(local)
      TimeOrDateTime.wrap(local) {|wrapped|
        wrapped - @utc_total_offset
      }
    end
    
    # Returns true if and only if toi has the same utc_offset, std_offset
    # and abbreviation as this TimezoneOffsetInfo.
    def ==(toi)
      toi.respond_to?(:utc_offset) && toi.respond_to?(:std_offset) && toi.respond_to?(:abbreviation) &&
        utc_offset == toi.utc_offset && std_offset == toi.std_offset && abbreviation == toi.abbreviation
    end
    
    # Returns true if and only if toi has the same utc_offset, std_offset
    # and abbreviation as this TimezoneOffsetInfo.
    def eql?(toi)
      self == toi
    end
    
    # Returns a hash of this TimezoneOffsetInfo.
    def hash
      utc_offset.hash ^ std_offset.hash ^ abbreviation.hash
    end
    
    # Returns internal object state as a programmer-readable string.
    def inspect
      "#<#{self.class}: #@utc_offset,#@std_offset,#@abbreviation>"
    end
  end
end
