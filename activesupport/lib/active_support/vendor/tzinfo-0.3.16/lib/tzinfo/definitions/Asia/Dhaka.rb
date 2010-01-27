require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Dhaka
        include TimezoneDefinition
        
        timezone 'Asia/Dhaka' do |tz|
          tz.offset :o0, 21700, 0, :LMT
          tz.offset :o1, 21200, 0, :HMT
          tz.offset :o2, 23400, 0, :BURT
          tz.offset :o3, 19800, 0, :IST
          tz.offset :o4, 21600, 0, :DACT
          tz.offset :o5, 21600, 0, :BDT
          tz.offset :o6, 21600, 3600, :BDST
          
          tz.transition 1889, 12, :o1, 2083422167, 864
          tz.transition 1941, 9, :o2, 524937943, 216
          tz.transition 1942, 5, :o3, 116663723, 48
          tz.transition 1942, 8, :o2, 116668957, 48
          tz.transition 1951, 9, :o4, 116828123, 48
          tz.transition 1971, 3, :o5, 38772000
          tz.transition 2009, 6, :o6, 1246294800
          tz.transition 2009, 12, :o5, 1262278800
          tz.transition 2010, 3, :o6, 1270054800
          tz.transition 2010, 10, :o5, 1288544400
          tz.transition 2011, 3, :o6, 1301590800
          tz.transition 2011, 10, :o5, 1320080400
          tz.transition 2012, 3, :o6, 1333213200
          tz.transition 2012, 10, :o5, 1351702800
          tz.transition 2013, 3, :o6, 1364749200
          tz.transition 2013, 10, :o5, 1383238800
          tz.transition 2014, 3, :o6, 1396285200
          tz.transition 2014, 10, :o5, 1414774800
          tz.transition 2015, 3, :o6, 1427821200
          tz.transition 2015, 10, :o5, 1446310800
          tz.transition 2016, 3, :o6, 1459443600
          tz.transition 2016, 10, :o5, 1477933200
          tz.transition 2017, 3, :o6, 1490979600
          tz.transition 2017, 10, :o5, 1509469200
          tz.transition 2018, 3, :o6, 1522515600
          tz.transition 2018, 10, :o5, 1541005200
          tz.transition 2019, 3, :o6, 1554051600
          tz.transition 2019, 10, :o5, 1572541200
          tz.transition 2020, 3, :o6, 1585674000
          tz.transition 2020, 10, :o5, 1604163600
          tz.transition 2021, 3, :o6, 1617210000
          tz.transition 2021, 10, :o5, 1635699600
          tz.transition 2022, 3, :o6, 1648746000
          tz.transition 2022, 10, :o5, 1667235600
          tz.transition 2023, 3, :o6, 1680282000
          tz.transition 2023, 10, :o5, 1698771600
          tz.transition 2024, 3, :o6, 1711904400
          tz.transition 2024, 10, :o5, 1730394000
          tz.transition 2025, 3, :o6, 1743440400
          tz.transition 2025, 10, :o5, 1761930000
          tz.transition 2026, 3, :o6, 1774976400
          tz.transition 2026, 10, :o5, 1793466000
          tz.transition 2027, 3, :o6, 1806512400
          tz.transition 2027, 10, :o5, 1825002000
          tz.transition 2028, 3, :o6, 1838134800
          tz.transition 2028, 10, :o5, 1856624400
          tz.transition 2029, 3, :o6, 1869670800
          tz.transition 2029, 10, :o5, 1888160400
          tz.transition 2030, 3, :o6, 1901206800
          tz.transition 2030, 10, :o5, 1919696400
          tz.transition 2031, 3, :o6, 1932742800
          tz.transition 2031, 10, :o5, 1951232400
          tz.transition 2032, 3, :o6, 1964365200
          tz.transition 2032, 10, :o5, 1982854800
          tz.transition 2033, 3, :o6, 1995901200
          tz.transition 2033, 10, :o5, 2014390800
          tz.transition 2034, 3, :o6, 2027437200
          tz.transition 2034, 10, :o5, 2045926800
          tz.transition 2035, 3, :o6, 2058973200
          tz.transition 2035, 10, :o5, 2077462800
          tz.transition 2036, 3, :o6, 2090595600
          tz.transition 2036, 10, :o5, 2109085200
          tz.transition 2037, 3, :o6, 2122131600
          tz.transition 2037, 10, :o5, 2140621200
          tz.transition 2038, 3, :o6, 59172341, 24
          tz.transition 2038, 10, :o5, 59177477, 24
          tz.transition 2039, 3, :o6, 59181101, 24
          tz.transition 2039, 10, :o5, 59186237, 24
          tz.transition 2040, 3, :o6, 59189885, 24
          tz.transition 2040, 10, :o5, 59195021, 24
          tz.transition 2041, 3, :o6, 59198645, 24
          tz.transition 2041, 10, :o5, 59203781, 24
          tz.transition 2042, 3, :o6, 59207405, 24
          tz.transition 2042, 10, :o5, 59212541, 24
          tz.transition 2043, 3, :o6, 59216165, 24
          tz.transition 2043, 10, :o5, 59221301, 24
          tz.transition 2044, 3, :o6, 59224949, 24
          tz.transition 2044, 10, :o5, 59230085, 24
          tz.transition 2045, 3, :o6, 59233709, 24
          tz.transition 2045, 10, :o5, 59238845, 24
          tz.transition 2046, 3, :o6, 59242469, 24
          tz.transition 2046, 10, :o5, 59247605, 24
          tz.transition 2047, 3, :o6, 59251229, 24
          tz.transition 2047, 10, :o5, 59256365, 24
          tz.transition 2048, 3, :o6, 59260013, 24
          tz.transition 2048, 10, :o5, 59265149, 24
          tz.transition 2049, 3, :o6, 59268773, 24
          tz.transition 2049, 10, :o5, 59273909, 24
          tz.transition 2050, 3, :o6, 59277533, 24
          tz.transition 2050, 10, :o5, 59282669, 24
        end
      end
    end
  end
end
