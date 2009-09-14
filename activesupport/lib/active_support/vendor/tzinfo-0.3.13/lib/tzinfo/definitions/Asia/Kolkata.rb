require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Kolkata
        include TimezoneDefinition
        
        timezone 'Asia/Kolkata' do |tz|
          tz.offset :o0, 21208, 0, :LMT
          tz.offset :o1, 21200, 0, :HMT
          tz.offset :o2, 23400, 0, :BURT
          tz.offset :o3, 19800, 0, :IST
          tz.offset :o4, 19800, 3600, :IST
          
          tz.transition 1879, 12, :o1, 26003324749, 10800
          tz.transition 1941, 9, :o2, 524937943, 216
          tz.transition 1942, 5, :o3, 116663723, 48
          tz.transition 1942, 8, :o4, 116668957, 48
          tz.transition 1945, 10, :o3, 116723675, 48
        end
      end
    end
  end
end
