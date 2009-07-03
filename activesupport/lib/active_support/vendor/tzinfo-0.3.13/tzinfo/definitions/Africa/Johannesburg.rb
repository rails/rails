require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Africa
      module Johannesburg
        include TimezoneDefinition
        
        timezone 'Africa/Johannesburg' do |tz|
          tz.offset :o0, 6720, 0, :LMT
          tz.offset :o1, 5400, 0, :SAST
          tz.offset :o2, 7200, 0, :SAST
          tz.offset :o3, 7200, 3600, :SAST
          
          tz.transition 1892, 2, :o1, 108546139, 45
          tz.transition 1903, 2, :o2, 38658791, 16
          tz.transition 1942, 9, :o3, 4861245, 2
          tz.transition 1943, 3, :o2, 58339307, 24
          tz.transition 1943, 9, :o3, 4861973, 2
          tz.transition 1944, 3, :o2, 58348043, 24
        end
      end
    end
  end
end
