require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module America
      module La_Paz
        include TimezoneDefinition
        
        timezone 'America/La_Paz' do |tz|
          tz.offset :o0, -16356, 0, :LMT
          tz.offset :o1, -16356, 0, :CMT
          tz.offset :o2, -16356, 3600, :BOST
          tz.offset :o3, -14400, 0, :BOT
          
          tz.transition 1890, 1, :o1, 17361854563, 7200
          tz.transition 1931, 10, :o2, 17471733763, 7200
          tz.transition 1932, 3, :o3, 17472871063, 7200
        end
      end
    end
  end
end
