require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Etc
      module UTC
        include TimezoneDefinition
        
        timezone 'Etc/UTC' do |tz|
          tz.offset :o0, 0, 0, :UTC
          
        end
      end
    end
  end
end
