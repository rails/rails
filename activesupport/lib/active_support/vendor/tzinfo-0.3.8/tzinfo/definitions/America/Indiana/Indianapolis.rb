require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module America
      module Indiana
        module Indianapolis
          include TimezoneDefinition
          
          timezone 'America/Indiana/Indianapolis' do |tz|
            tz.offset :o0, -20678, 0, :LMT
            tz.offset :o1, -21600, 0, :CST
            tz.offset :o2, -21600, 3600, :CDT
            tz.offset :o3, -21600, 3600, :CWT
            tz.offset :o4, -21600, 3600, :CPT
            tz.offset :o5, -18000, 0, :EST
            tz.offset :o6, -18000, 3600, :EDT
            
            tz.transition 1883, 11, :o1, 9636533, 4
            tz.transition 1918, 3, :o2, 14530103, 6
            tz.transition 1918, 10, :o1, 58125451, 24
            tz.transition 1919, 3, :o2, 14532287, 6
            tz.transition 1919, 10, :o1, 58134187, 24
            tz.transition 1941, 6, :o2, 14581007, 6
            tz.transition 1941, 9, :o1, 58326379, 24
            tz.transition 1942, 2, :o3, 14582399, 6
            tz.transition 1945, 8, :o4, 58360379, 24
            tz.transition 1945, 9, :o1, 58361491, 24
            tz.transition 1946, 4, :o2, 14591633, 6
            tz.transition 1946, 9, :o1, 58370227, 24
            tz.transition 1947, 4, :o2, 14593817, 6
            tz.transition 1947, 9, :o1, 58378963, 24
            tz.transition 1948, 4, :o2, 14596001, 6
            tz.transition 1948, 9, :o1, 58387699, 24
            tz.transition 1949, 4, :o2, 14598185, 6
            tz.transition 1949, 9, :o1, 58396435, 24
            tz.transition 1950, 4, :o2, 14600411, 6
            tz.transition 1950, 9, :o1, 58405171, 24
            tz.transition 1951, 4, :o2, 14602595, 6
            tz.transition 1951, 9, :o1, 58414075, 24
            tz.transition 1952, 4, :o2, 14604779, 6
            tz.transition 1952, 9, :o1, 58422811, 24
            tz.transition 1953, 4, :o2, 14606963, 6
            tz.transition 1953, 9, :o1, 58431547, 24
            tz.transition 1954, 4, :o2, 14609147, 6
            tz.transition 1954, 9, :o1, 58440283, 24
            tz.transition 1955, 4, :o5, 14611331, 6
            tz.transition 1957, 9, :o1, 58466659, 24
            tz.transition 1958, 4, :o5, 14617925, 6
            tz.transition 1969, 4, :o6, 58568131, 24
            tz.transition 1969, 10, :o5, 9762083, 4
            tz.transition 1970, 4, :o6, 9961200
            tz.transition 1970, 10, :o5, 25682400
            tz.transition 2006, 4, :o6, 1143961200
            tz.transition 2006, 10, :o5, 1162101600
            tz.transition 2007, 3, :o6, 1173596400
            tz.transition 2007, 11, :o5, 1194156000
            tz.transition 2008, 3, :o6, 1205046000
            tz.transition 2008, 11, :o5, 1225605600
            tz.transition 2009, 3, :o6, 1236495600
            tz.transition 2009, 11, :o5, 1257055200
            tz.transition 2010, 3, :o6, 1268550000
            tz.transition 2010, 11, :o5, 1289109600
            tz.transition 2011, 3, :o6, 1299999600
            tz.transition 2011, 11, :o5, 1320559200
            tz.transition 2012, 3, :o6, 1331449200
            tz.transition 2012, 11, :o5, 1352008800
            tz.transition 2013, 3, :o6, 1362898800
            tz.transition 2013, 11, :o5, 1383458400
            tz.transition 2014, 3, :o6, 1394348400
            tz.transition 2014, 11, :o5, 1414908000
            tz.transition 2015, 3, :o6, 1425798000
            tz.transition 2015, 11, :o5, 1446357600
            tz.transition 2016, 3, :o6, 1457852400
            tz.transition 2016, 11, :o5, 1478412000
            tz.transition 2017, 3, :o6, 1489302000
            tz.transition 2017, 11, :o5, 1509861600
            tz.transition 2018, 3, :o6, 1520751600
            tz.transition 2018, 11, :o5, 1541311200
            tz.transition 2019, 3, :o6, 1552201200
            tz.transition 2019, 11, :o5, 1572760800
            tz.transition 2020, 3, :o6, 1583650800
            tz.transition 2020, 11, :o5, 1604210400
            tz.transition 2021, 3, :o6, 1615705200
            tz.transition 2021, 11, :o5, 1636264800
            tz.transition 2022, 3, :o6, 1647154800
            tz.transition 2022, 11, :o5, 1667714400
            tz.transition 2023, 3, :o6, 1678604400
            tz.transition 2023, 11, :o5, 1699164000
            tz.transition 2024, 3, :o6, 1710054000
            tz.transition 2024, 11, :o5, 1730613600
            tz.transition 2025, 3, :o6, 1741503600
            tz.transition 2025, 11, :o5, 1762063200
            tz.transition 2026, 3, :o6, 1772953200
            tz.transition 2026, 11, :o5, 1793512800
            tz.transition 2027, 3, :o6, 1805007600
            tz.transition 2027, 11, :o5, 1825567200
            tz.transition 2028, 3, :o6, 1836457200
            tz.transition 2028, 11, :o5, 1857016800
            tz.transition 2029, 3, :o6, 1867906800
            tz.transition 2029, 11, :o5, 1888466400
            tz.transition 2030, 3, :o6, 1899356400
            tz.transition 2030, 11, :o5, 1919916000
            tz.transition 2031, 3, :o6, 1930806000
            tz.transition 2031, 11, :o5, 1951365600
            tz.transition 2032, 3, :o6, 1962860400
            tz.transition 2032, 11, :o5, 1983420000
            tz.transition 2033, 3, :o6, 1994310000
            tz.transition 2033, 11, :o5, 2014869600
            tz.transition 2034, 3, :o6, 2025759600
            tz.transition 2034, 11, :o5, 2046319200
            tz.transition 2035, 3, :o6, 2057209200
            tz.transition 2035, 11, :o5, 2077768800
            tz.transition 2036, 3, :o6, 2088658800
            tz.transition 2036, 11, :o5, 2109218400
            tz.transition 2037, 3, :o6, 2120108400
            tz.transition 2037, 11, :o5, 2140668000
            tz.transition 2038, 3, :o6, 59171923, 24
            tz.transition 2038, 11, :o5, 9862939, 4
            tz.transition 2039, 3, :o6, 59180659, 24
            tz.transition 2039, 11, :o5, 9864395, 4
            tz.transition 2040, 3, :o6, 59189395, 24
            tz.transition 2040, 11, :o5, 9865851, 4
            tz.transition 2041, 3, :o6, 59198131, 24
            tz.transition 2041, 11, :o5, 9867307, 4
            tz.transition 2042, 3, :o6, 59206867, 24
            tz.transition 2042, 11, :o5, 9868763, 4
            tz.transition 2043, 3, :o6, 59215603, 24
            tz.transition 2043, 11, :o5, 9870219, 4
            tz.transition 2044, 3, :o6, 59224507, 24
            tz.transition 2044, 11, :o5, 9871703, 4
            tz.transition 2045, 3, :o6, 59233243, 24
            tz.transition 2045, 11, :o5, 9873159, 4
            tz.transition 2046, 3, :o6, 59241979, 24
            tz.transition 2046, 11, :o5, 9874615, 4
            tz.transition 2047, 3, :o6, 59250715, 24
            tz.transition 2047, 11, :o5, 9876071, 4
            tz.transition 2048, 3, :o6, 59259451, 24
            tz.transition 2048, 11, :o5, 9877527, 4
            tz.transition 2049, 3, :o6, 59268355, 24
            tz.transition 2049, 11, :o5, 9879011, 4
            tz.transition 2050, 3, :o6, 59277091, 24
            tz.transition 2050, 11, :o5, 9880467, 4
          end
        end
      end
    end
  end
end
