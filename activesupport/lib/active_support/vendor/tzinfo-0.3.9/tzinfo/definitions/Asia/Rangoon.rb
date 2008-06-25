require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Rangoon
        include TimezoneDefinition
        
        timezone 'Asia/Rangoon' do |tz|
          tz.offset :o0, 23080, 0, :LMT
          tz.offset :o1, 23076, 0, :RMT
          tz.offset :o2, 23400, 0, :BURT
          tz.offset :o3, 32400, 0, :JST
          tz.offset :o4, 23400, 0, :MMT
          
          tz.transition 1879, 12, :o1, 5200664903, 2160
          tz.transition 1919, 12, :o2, 5813578159, 2400
          tz.transition 1942, 4, :o3, 116663051, 48
          tz.transition 1945, 5, :o4, 19452625, 8
        end
      end
    end
  end
end
