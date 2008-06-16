require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Europe
      module Sarajevo
        include TimezoneDefinition
        
        linked_timezone 'Europe/Sarajevo', 'Europe/Belgrade'
      end
    end
  end
end
