require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Singapore
        include TimezoneDefinition
        
        timezone 'Asia/Singapore' do |tz|
          tz.offset :o0, 24925, 0, :LMT
          tz.offset :o1, 24925, 0, :SMT
          tz.offset :o2, 25200, 0, :MALT
          tz.offset :o3, 25200, 1200, :MALST
          tz.offset :o4, 26400, 0, :MALT
          tz.offset :o5, 27000, 0, :MALT
          tz.offset :o6, 32400, 0, :JST
          tz.offset :o7, 27000, 0, :SGT
          tz.offset :o8, 28800, 0, :SGT
          
          tz.transition 1900, 12, :o1, 8347571291, 3456
          tz.transition 1905, 5, :o2, 8353142363, 3456
          tz.transition 1932, 12, :o3, 58249757, 24
          tz.transition 1935, 12, :o4, 87414055, 36
          tz.transition 1941, 8, :o5, 87488575, 36
          tz.transition 1942, 2, :o6, 38886499, 16
          tz.transition 1945, 9, :o5, 19453681, 8
          tz.transition 1965, 8, :o7, 39023699, 16
          tz.transition 1981, 12, :o8, 378664200
        end
      end
    end
  end
end
