require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Pacific
      module Guam
        include TimezoneDefinition
        
        timezone 'Pacific/Guam' do |tz|
          tz.offset :o0, -51660, 0, :LMT
          tz.offset :o1, 34740, 0, :LMT
          tz.offset :o2, 36000, 0, :GST
          tz.offset :o3, 36000, 0, :ChST
          
          tz.transition 1844, 12, :o1, 1149567407, 480
          tz.transition 1900, 12, :o2, 1159384847, 480
          tz.transition 2000, 12, :o3, 977493600
        end
      end
    end
  end
end
