require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Atlantic
      module Cape_Verde
        include TimezoneDefinition
        
        timezone 'Atlantic/Cape_Verde' do |tz|
          tz.offset :o0, -5644, 0, :LMT
          tz.offset :o1, -7200, 0, :CVT
          tz.offset :o2, -7200, 3600, :CVST
          tz.offset :o3, -3600, 0, :CVT
          
          tz.transition 1907, 1, :o1, 52219653811, 21600
          tz.transition 1942, 9, :o2, 29167243, 12
          tz.transition 1945, 10, :o1, 58361845, 24
          tz.transition 1975, 11, :o3, 186120000
        end
      end
    end
  end
end
