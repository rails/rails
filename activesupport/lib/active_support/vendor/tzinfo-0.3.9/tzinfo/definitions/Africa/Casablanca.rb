require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Africa
      module Casablanca
        include TimezoneDefinition
        
        timezone 'Africa/Casablanca' do |tz|
          tz.offset :o0, -1820, 0, :LMT
          tz.offset :o1, 0, 0, :WET
          tz.offset :o2, 0, 3600, :WEST
          tz.offset :o3, 3600, 0, :CET
          
          tz.transition 1913, 10, :o1, 10454687371, 4320
          tz.transition 1939, 9, :o2, 4859037, 2
          tz.transition 1939, 11, :o1, 58310075, 24
          tz.transition 1940, 2, :o2, 4859369, 2
          tz.transition 1945, 11, :o1, 58362659, 24
          tz.transition 1950, 6, :o2, 4866887, 2
          tz.transition 1950, 10, :o1, 58406003, 24
          tz.transition 1967, 6, :o2, 2439645, 1
          tz.transition 1967, 9, :o1, 58554347, 24
          tz.transition 1974, 6, :o2, 141264000
          tz.transition 1974, 8, :o1, 147222000
          tz.transition 1976, 5, :o2, 199756800
          tz.transition 1976, 7, :o1, 207702000
          tz.transition 1977, 5, :o2, 231292800
          tz.transition 1977, 9, :o1, 244249200
          tz.transition 1978, 6, :o2, 265507200
          tz.transition 1978, 8, :o1, 271033200
          tz.transition 1984, 3, :o3, 448243200
          tz.transition 1985, 12, :o1, 504918000
          tz.transition 2008, 6, :o2, 1212278400
          tz.transition 2008, 9, :o1, 1222556400
        end
      end
    end
  end
end
