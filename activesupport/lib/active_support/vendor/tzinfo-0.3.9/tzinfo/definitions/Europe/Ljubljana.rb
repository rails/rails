require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Europe
      module Ljubljana
        include TimezoneDefinition
        
        linked_timezone 'Europe/Ljubljana', 'Europe/Belgrade'
      end
    end
  end
end
