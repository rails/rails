require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Dhaka
        include TimezoneDefinition
        
        timezone 'Asia/Dhaka' do |tz|
          tz.offset :o0, 21700, 0, :LMT
          tz.offset :o1, 21200, 0, :HMT
          tz.offset :o2, 23400, 0, :BURT
          tz.offset :o3, 19800, 0, :IST
          tz.offset :o4, 21600, 0, :DACT
          tz.offset :o5, 21600, 0, :BDT
          
          tz.transition 1889, 12, :o1, 2083422167, 864
          tz.transition 1941, 9, :o2, 524937943, 216
          tz.transition 1942, 5, :o3, 116663723, 48
          tz.transition 1942, 8, :o2, 116668957, 48
          tz.transition 1951, 9, :o4, 116828123, 48
          tz.transition 1971, 3, :o5, 38772000
        end
      end
    end
  end
end
