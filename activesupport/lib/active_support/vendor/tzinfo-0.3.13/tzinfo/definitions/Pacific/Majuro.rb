require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Pacific
      module Majuro
        include TimezoneDefinition
        
        timezone 'Pacific/Majuro' do |tz|
          tz.offset :o0, 41088, 0, :LMT
          tz.offset :o1, 39600, 0, :MHT
          tz.offset :o2, 43200, 0, :MHT
          
          tz.transition 1900, 12, :o1, 1086923261, 450
          tz.transition 1969, 9, :o2, 58571881, 24
        end
      end
    end
  end
end
