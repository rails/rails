require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Europe
      module Skopje
        include TimezoneDefinition
        
        linked_timezone 'Europe/Skopje', 'Europe/Belgrade'
      end
    end
  end
end
