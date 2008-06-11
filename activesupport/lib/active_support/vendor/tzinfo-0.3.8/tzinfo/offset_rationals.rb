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
  
  # Provides a method for getting Rationals for a timezone offset in seconds.
  # Pre-reduced rationals are returned for all the half-hour intervals between
  # -14 and +14 hours to avoid having to call gcd at runtime.  
  module OffsetRationals #:nodoc:
    @@rational_cache = {
      -50400 => Rational(-7,12),
      -48600 => Rational(-9,16),
      -46800 => Rational(-13,24),
      -45000 => Rational(-25,48),
      -43200 => Rational(-1,2),
      -41400 => Rational(-23,48),
      -39600 => Rational(-11,24),
      -37800 => Rational(-7,16),
      -36000 => Rational(-5,12),
      -34200 => Rational(-19,48),
      -32400 => Rational(-3,8),
      -30600 => Rational(-17,48),
      -28800 => Rational(-1,3),
      -27000 => Rational(-5,16),
      -25200 => Rational(-7,24),
      -23400 => Rational(-13,48),
      -21600 => Rational(-1,4),
      -19800 => Rational(-11,48),
      -18000 => Rational(-5,24),
      -16200 => Rational(-3,16),
      -14400 => Rational(-1,6),
      -12600 => Rational(-7,48),
      -10800 => Rational(-1,8),
       -9000 => Rational(-5,48),
       -7200 => Rational(-1,12),
       -5400 => Rational(-1,16),
       -3600 => Rational(-1,24),
       -1800 => Rational(-1,48),
           0 => Rational(0,1),
        1800 => Rational(1,48),
        3600 => Rational(1,24),
        5400 => Rational(1,16),
        7200 => Rational(1,12),
        9000 => Rational(5,48),
       10800 => Rational(1,8),
       12600 => Rational(7,48),
       14400 => Rational(1,6),
       16200 => Rational(3,16),
       18000 => Rational(5,24),
       19800 => Rational(11,48),
       21600 => Rational(1,4),
       23400 => Rational(13,48),
       25200 => Rational(7,24),
       27000 => Rational(5,16),
       28800 => Rational(1,3),
       30600 => Rational(17,48),
       32400 => Rational(3,8),
       34200 => Rational(19,48),
       36000 => Rational(5,12),
       37800 => Rational(7,16),
       39600 => Rational(11,24),
       41400 => Rational(23,48),
       43200 => Rational(1,2),
       45000 => Rational(25,48),
       46800 => Rational(13,24),
       48600 => Rational(9,16),
       50400 => Rational(7,12)}
    
    # Returns a Rational expressing the fraction of a day that offset in 
    # seconds represents (i.e. equivalent to Rational(offset, 86400)). 
    def rational_for_offset(offset)
      @@rational_cache[offset] || Rational(offset, 86400)      
    end
    module_function :rational_for_offset
  end
end
