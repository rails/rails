require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Katmandu
        include TimezoneDefinition
        
        timezone 'Asia/Katmandu' do |tz|
          tz.offset :o0, 20476, 0, :LMT
          tz.offset :o1, 19800, 0, :IST
          tz.offset :o2, 20700, 0, :NPT
          
          tz.transition 1919, 12, :o1, 52322204081, 21600
          tz.transition 1985, 12, :o2, 504901800
        end
      end
    end
  end
end
