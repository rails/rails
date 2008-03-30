require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Muscat
        include TimezoneDefinition
        
        timezone 'Asia/Muscat' do |tz|
          tz.offset :o0, 14060, 0, :LMT
          tz.offset :o1, 14400, 0, :GST
          
          tz.transition 1919, 12, :o1, 10464441137, 4320
        end
      end
    end
  end
end
