require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module America
      module Bogota
        include TimezoneDefinition
        
        timezone 'America/Bogota' do |tz|
          tz.offset :o0, -17780, 0, :LMT
          tz.offset :o1, -17780, 0, :BMT
          tz.offset :o2, -18000, 0, :COT
          tz.offset :o3, -18000, 3600, :COST
          
          tz.transition 1884, 3, :o1, 10407954409, 4320
          tz.transition 1914, 11, :o2, 10456385929, 4320
          tz.transition 1992, 5, :o3, 704869200
          tz.transition 1993, 4, :o2, 733896000
        end
      end
    end
  end
end
