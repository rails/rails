require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module America
      module Argentina
        module San_Juan
          include TimezoneDefinition
          
          timezone 'America/Argentina/San_Juan' do |tz|
            tz.offset :o0, -16444, 0, :LMT
            tz.offset :o1, -15408, 0, :CMT
            tz.offset :o2, -14400, 0, :ART
            tz.offset :o3, -14400, 3600, :ARST
            tz.offset :o4, -10800, 0, :ART
            tz.offset :o5, -10800, 3600, :ARST
            tz.offset :o6, -14400, 0, :WART
            
            tz.transition 1894, 10, :o1, 52123666111, 21600
            tz.transition 1920, 5, :o2, 1453467407, 600
            tz.transition 1930, 12, :o3, 7278935, 3
            tz.transition 1931, 4, :o2, 19411461, 8
            tz.transition 1931, 10, :o3, 7279889, 3
            tz.transition 1932, 3, :o2, 19414141, 8
            tz.transition 1932, 11, :o3, 7281038, 3
            tz.transition 1933, 3, :o2, 19417061, 8
            tz.transition 1933, 11, :o3, 7282133, 3
            tz.transition 1934, 3, :o2, 19419981, 8
            tz.transition 1934, 11, :o3, 7283228, 3
            tz.transition 1935, 3, :o2, 19422901, 8
            tz.transition 1935, 11, :o3, 7284323, 3
            tz.transition 1936, 3, :o2, 19425829, 8
            tz.transition 1936, 11, :o3, 7285421, 3
            tz.transition 1937, 3, :o2, 19428749, 8
            tz.transition 1937, 11, :o3, 7286516, 3
            tz.transition 1938, 3, :o2, 19431669, 8
            tz.transition 1938, 11, :o3, 7287611, 3
            tz.transition 1939, 3, :o2, 19434589, 8
            tz.transition 1939, 11, :o3, 7288706, 3
            tz.transition 1940, 3, :o2, 19437517, 8
            tz.transition 1940, 7, :o3, 7289435, 3
            tz.transition 1941, 6, :o2, 19441285, 8
            tz.transition 1941, 10, :o3, 7290848, 3
            tz.transition 1943, 8, :o2, 19447501, 8
            tz.transition 1943, 10, :o3, 7293038, 3
            tz.transition 1946, 3, :o2, 19455045, 8
            tz.transition 1946, 10, :o3, 7296284, 3
            tz.transition 1963, 10, :o2, 19506429, 8
            tz.transition 1963, 12, :o3, 7315136, 3
            tz.transition 1964, 3, :o2, 19507645, 8
            tz.transition 1964, 10, :o3, 7316051, 3
            tz.transition 1965, 3, :o2, 19510565, 8
            tz.transition 1965, 10, :o3, 7317146, 3
            tz.transition 1966, 3, :o2, 19513485, 8
            tz.transition 1966, 10, :o3, 7318241, 3
            tz.transition 1967, 4, :o2, 19516661, 8
            tz.transition 1967, 10, :o3, 7319294, 3
            tz.transition 1968, 4, :o2, 19519629, 8
            tz.transition 1968, 10, :o3, 7320407, 3
            tz.transition 1969, 4, :o2, 19522541, 8
            tz.transition 1969, 10, :o4, 7321499, 3
            tz.transition 1974, 1, :o5, 128142000
            tz.transition 1974, 5, :o4, 136605600
            tz.transition 1988, 12, :o5, 596948400
            tz.transition 1989, 3, :o4, 605066400
            tz.transition 1989, 10, :o5, 624423600
            tz.transition 1990, 3, :o4, 636516000
            tz.transition 1990, 10, :o5, 656478000
            tz.transition 1991, 3, :o6, 667792800
            tz.transition 1991, 5, :o4, 673588800
            tz.transition 1991, 10, :o5, 687927600
            tz.transition 1992, 3, :o4, 699415200
            tz.transition 1992, 10, :o5, 719377200
            tz.transition 1993, 3, :o4, 731469600
            tz.transition 1999, 10, :o3, 938919600
            tz.transition 2000, 3, :o4, 952052400
            tz.transition 2004, 5, :o6, 1085972400
            tz.transition 2004, 7, :o4, 1090728000
            tz.transition 2007, 12, :o5, 1198983600
            tz.transition 2008, 3, :o4, 1205632800
          end
        end
      end
    end
  end
end
