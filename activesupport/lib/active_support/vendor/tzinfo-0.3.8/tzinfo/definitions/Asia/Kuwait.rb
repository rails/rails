require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Kuwait
        include TimezoneDefinition
        
        timezone 'Asia/Kuwait' do |tz|
          tz.offset :o0, 11516, 0, :LMT
          tz.offset :o1, 10800, 0, :AST
          
          tz.transition 1949, 12, :o1, 52558899121, 21600
        end
      end
    end
  end
end
