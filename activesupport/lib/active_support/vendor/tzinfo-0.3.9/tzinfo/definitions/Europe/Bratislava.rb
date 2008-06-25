require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Europe
      module Bratislava
        include TimezoneDefinition
        
        linked_timezone 'Europe/Bratislava', 'Europe/Prague'
      end
    end
  end
end
