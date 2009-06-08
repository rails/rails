require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Katmandu
        include TimezoneDefinition
        
        linked_timezone 'Asia/Katmandu', 'Asia/Kathmandu'
      end
    end
  end
end
