require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module America
      module Guyana
        include TimezoneDefinition
        
        timezone 'America/Guyana' do |tz|
          tz.offset :o0, -13960, 0, :LMT
          tz.offset :o1, -13500, 0, :GBGT
          tz.offset :o2, -13500, 0, :GYT
          tz.offset :o3, -10800, 0, :GYT
          tz.offset :o4, -14400, 0, :GYT
          
          tz.transition 1915, 3, :o1, 5228404549, 2160
          tz.transition 1966, 5, :o2, 78056693, 32
          tz.transition 1975, 7, :o3, 176010300
          tz.transition 1991, 1, :o4, 662698800
        end
      end
    end
  end
end
