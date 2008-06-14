require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Kabul
        include TimezoneDefinition
        
        timezone 'Asia/Kabul' do |tz|
          tz.offset :o0, 16608, 0, :LMT
          tz.offset :o1, 14400, 0, :AFT
          tz.offset :o2, 16200, 0, :AFT
          
          tz.transition 1889, 12, :o1, 2170231477, 900
          tz.transition 1944, 12, :o2, 7294369, 3
        end
      end
    end
  end
end
