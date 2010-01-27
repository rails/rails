require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Europe
      module Zagreb
        include TimezoneDefinition
        
        linked_timezone 'Europe/Zagreb', 'Europe/Belgrade'
      end
    end
  end
end
