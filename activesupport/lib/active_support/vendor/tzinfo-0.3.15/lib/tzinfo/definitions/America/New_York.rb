require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module America
      module New_York
        include TimezoneDefinition
        
        timezone 'America/New_York' do |tz|
          tz.offset :o0, -17762, 0, :LMT
          tz.offset :o1, -18000, 0, :EST
          tz.offset :o2, -18000, 3600, :EDT
          tz.offset :o3, -18000, 3600, :EWT
          tz.offset :o4, -18000, 3600, :EPT
          
          tz.transition 1883, 11, :o1, 57819197, 24
          tz.transition 1918, 3, :o2, 58120411, 24
          tz.transition 1918, 10, :o1, 9687575, 4
          tz.transition 1919, 3, :o2, 58129147, 24
          tz.transition 1919, 10, :o1, 9689031, 4
          tz.transition 1920, 3, :o2, 58137883, 24
          tz.transition 1920, 10, :o1, 9690515, 4
          tz.transition 1921, 4, :o2, 58147291, 24
          tz.transition 1921, 9, :o1, 9691831, 4
          tz.transition 1922, 4, :o2, 58156195, 24
          tz.transition 1922, 9, :o1, 9693287, 4
          tz.transition 1923, 4, :o2, 58164931, 24
          tz.transition 1923, 9, :o1, 9694771, 4
          tz.transition 1924, 4, :o2, 58173667, 24
          tz.transition 1924, 9, :o1, 9696227, 4
          tz.transition 1925, 4, :o2, 58182403, 24
          tz.transition 1925, 9, :o1, 9697683, 4
          tz.transition 1926, 4, :o2, 58191139, 24
          tz.transition 1926, 9, :o1, 9699139, 4
          tz.transition 1927, 4, :o2, 58199875, 24
          tz.transition 1927, 9, :o1, 9700595, 4
          tz.transition 1928, 4, :o2, 58208779, 24
          tz.transition 1928, 9, :o1, 9702079, 4
          tz.transition 1929, 4, :o2, 58217515, 24
          tz.transition 1929, 9, :o1, 9703535, 4
          tz.transition 1930, 4, :o2, 58226251, 24
          tz.transition 1930, 9, :o1, 9704991, 4
          tz.transition 1931, 4, :o2, 58234987, 24
          tz.transition 1931, 9, :o1, 9706447, 4
          tz.transition 1932, 4, :o2, 58243723, 24
          tz.transition 1932, 9, :o1, 9707903, 4
          tz.transition 1933, 4, :o2, 58252627, 24
          tz.transition 1933, 9, :o1, 9709359, 4
          tz.transition 1934, 4, :o2, 58261363, 24
          tz.transition 1934, 9, :o1, 9710843, 4
          tz.transition 1935, 4, :o2, 58270099, 24
          tz.transition 1935, 9, :o1, 9712299, 4
          tz.transition 1936, 4, :o2, 58278835, 24
          tz.transition 1936, 9, :o1, 9713755, 4
          tz.transition 1937, 4, :o2, 58287571, 24
          tz.transition 1937, 9, :o1, 9715211, 4
          tz.transition 1938, 4, :o2, 58296307, 24
          tz.transition 1938, 9, :o1, 9716667, 4
          tz.transition 1939, 4, :o2, 58305211, 24
          tz.transition 1939, 9, :o1, 9718123, 4
          tz.transition 1940, 4, :o2, 58313947, 24
          tz.transition 1940, 9, :o1, 9719607, 4
          tz.transition 1941, 4, :o2, 58322683, 24
          tz.transition 1941, 9, :o1, 9721063, 4
          tz.transition 1942, 2, :o3, 58329595, 24
          tz.transition 1945, 8, :o4, 58360379, 24
          tz.transition 1945, 9, :o1, 9726915, 4
          tz.transition 1946, 4, :o2, 58366531, 24
          tz.transition 1946, 9, :o1, 9728371, 4
          tz.transition 1947, 4, :o2, 58375267, 24
          tz.transition 1947, 9, :o1, 9729827, 4
          tz.transition 1948, 4, :o2, 58384003, 24
          tz.transition 1948, 9, :o1, 9731283, 4
          tz.transition 1949, 4, :o2, 58392739, 24
          tz.transition 1949, 9, :o1, 9732739, 4
          tz.transition 1950, 4, :o2, 58401643, 24
          tz.transition 1950, 9, :o1, 9734195, 4
          tz.transition 1951, 4, :o2, 58410379, 24
          tz.transition 1951, 9, :o1, 9735679, 4
          tz.transition 1952, 4, :o2, 58419115, 24
          tz.transition 1952, 9, :o1, 9737135, 4
          tz.transition 1953, 4, :o2, 58427851, 24
          tz.transition 1953, 9, :o1, 9738591, 4
          tz.transition 1954, 4, :o2, 58436587, 24
          tz.transition 1954, 9, :o1, 9740047, 4
          tz.transition 1955, 4, :o2, 58445323, 24
          tz.transition 1955, 10, :o1, 9741643, 4
          tz.transition 1956, 4, :o2, 58454227, 24
          tz.transition 1956, 10, :o1, 9743099, 4
          tz.transition 1957, 4, :o2, 58462963, 24
          tz.transition 1957, 10, :o1, 9744555, 4
          tz.transition 1958, 4, :o2, 58471699, 24
          tz.transition 1958, 10, :o1, 9746011, 4
          tz.transition 1959, 4, :o2, 58480435, 24
          tz.transition 1959, 10, :o1, 9747467, 4
          tz.transition 1960, 4, :o2, 58489171, 24
          tz.transition 1960, 10, :o1, 9748951, 4
          tz.transition 1961, 4, :o2, 58498075, 24
          tz.transition 1961, 10, :o1, 9750407, 4
          tz.transition 1962, 4, :o2, 58506811, 24
          tz.transition 1962, 10, :o1, 9751863, 4
          tz.transition 1963, 4, :o2, 58515547, 24
          tz.transition 1963, 10, :o1, 9753319, 4
          tz.transition 1964, 4, :o2, 58524283, 24
          tz.transition 1964, 10, :o1, 9754775, 4
          tz.transition 1965, 4, :o2, 58533019, 24
          tz.transition 1965, 10, :o1, 9756259, 4
          tz.transition 1966, 4, :o2, 58541755, 24
          tz.transition 1966, 10, :o1, 9757715, 4
          tz.transition 1967, 4, :o2, 58550659, 24
          tz.transition 1967, 10, :o1, 9759171, 4
          tz.transition 1968, 4, :o2, 58559395, 24
          tz.transition 1968, 10, :o1, 9760627, 4
          tz.transition 1969, 4, :o2, 58568131, 24
          tz.transition 1969, 10, :o1, 9762083, 4
          tz.transition 1970, 4, :o2, 9961200
          tz.transition 1970, 10, :o1, 25682400
          tz.transition 1971, 4, :o2, 41410800
          tz.transition 1971, 10, :o1, 57736800
          tz.transition 1972, 4, :o2, 73465200
          tz.transition 1972, 10, :o1, 89186400
          tz.transition 1973, 4, :o2, 104914800
          tz.transition 1973, 10, :o1, 120636000
          tz.transition 1974, 1, :o2, 126687600
          tz.transition 1974, 10, :o1, 152085600
          tz.transition 1975, 2, :o2, 162370800
          tz.transition 1975, 10, :o1, 183535200
          tz.transition 1976, 4, :o2, 199263600
          tz.transition 1976, 10, :o1, 215589600
          tz.transition 1977, 4, :o2, 230713200
          tz.transition 1977, 10, :o1, 247039200
          tz.transition 1978, 4, :o2, 262767600
          tz.transition 1978, 10, :o1, 278488800
          tz.transition 1979, 4, :o2, 294217200
          tz.transition 1979, 10, :o1, 309938400
          tz.transition 1980, 4, :o2, 325666800
          tz.transition 1980, 10, :o1, 341388000
          tz.transition 1981, 4, :o2, 357116400
          tz.transition 1981, 10, :o1, 372837600
          tz.transition 1982, 4, :o2, 388566000
          tz.transition 1982, 10, :o1, 404892000
          tz.transition 1983, 4, :o2, 420015600
          tz.transition 1983, 10, :o1, 436341600
          tz.transition 1984, 4, :o2, 452070000
          tz.transition 1984, 10, :o1, 467791200
          tz.transition 1985, 4, :o2, 483519600
          tz.transition 1985, 10, :o1, 499240800
          tz.transition 1986, 4, :o2, 514969200
          tz.transition 1986, 10, :o1, 530690400
          tz.transition 1987, 4, :o2, 544604400
          tz.transition 1987, 10, :o1, 562140000
          tz.transition 1988, 4, :o2, 576054000
          tz.transition 1988, 10, :o1, 594194400
          tz.transition 1989, 4, :o2, 607503600
          tz.transition 1989, 10, :o1, 625644000
          tz.transition 1990, 4, :o2, 638953200
          tz.transition 1990, 10, :o1, 657093600
          tz.transition 1991, 4, :o2, 671007600
          tz.transition 1991, 10, :o1, 688543200
          tz.transition 1992, 4, :o2, 702457200
          tz.transition 1992, 10, :o1, 719992800
          tz.transition 1993, 4, :o2, 733906800
          tz.transition 1993, 10, :o1, 752047200
          tz.transition 1994, 4, :o2, 765356400
          tz.transition 1994, 10, :o1, 783496800
          tz.transition 1995, 4, :o2, 796806000
          tz.transition 1995, 10, :o1, 814946400
          tz.transition 1996, 4, :o2, 828860400
          tz.transition 1996, 10, :o1, 846396000
          tz.transition 1997, 4, :o2, 860310000
          tz.transition 1997, 10, :o1, 877845600
          tz.transition 1998, 4, :o2, 891759600
          tz.transition 1998, 10, :o1, 909295200
          tz.transition 1999, 4, :o2, 923209200
          tz.transition 1999, 10, :o1, 941349600
          tz.transition 2000, 4, :o2, 954658800
          tz.transition 2000, 10, :o1, 972799200
          tz.transition 2001, 4, :o2, 986108400
          tz.transition 2001, 10, :o1, 1004248800
          tz.transition 2002, 4, :o2, 1018162800
          tz.transition 2002, 10, :o1, 1035698400
          tz.transition 2003, 4, :o2, 1049612400
          tz.transition 2003, 10, :o1, 1067148000
          tz.transition 2004, 4, :o2, 1081062000
          tz.transition 2004, 10, :o1, 1099202400
          tz.transition 2005, 4, :o2, 1112511600
          tz.transition 2005, 10, :o1, 1130652000
          tz.transition 2006, 4, :o2, 1143961200
          tz.transition 2006, 10, :o1, 1162101600
          tz.transition 2007, 3, :o2, 1173596400
          tz.transition 2007, 11, :o1, 1194156000
          tz.transition 2008, 3, :o2, 1205046000
          tz.transition 2008, 11, :o1, 1225605600
          tz.transition 2009, 3, :o2, 1236495600
          tz.transition 2009, 11, :o1, 1257055200
          tz.transition 2010, 3, :o2, 1268550000
          tz.transition 2010, 11, :o1, 1289109600
          tz.transition 2011, 3, :o2, 1299999600
          tz.transition 2011, 11, :o1, 1320559200
          tz.transition 2012, 3, :o2, 1331449200
          tz.transition 2012, 11, :o1, 1352008800
          tz.transition 2013, 3, :o2, 1362898800
          tz.transition 2013, 11, :o1, 1383458400
          tz.transition 2014, 3, :o2, 1394348400
          tz.transition 2014, 11, :o1, 1414908000
          tz.transition 2015, 3, :o2, 1425798000
          tz.transition 2015, 11, :o1, 1446357600
          tz.transition 2016, 3, :o2, 1457852400
          tz.transition 2016, 11, :o1, 1478412000
          tz.transition 2017, 3, :o2, 1489302000
          tz.transition 2017, 11, :o1, 1509861600
          tz.transition 2018, 3, :o2, 1520751600
          tz.transition 2018, 11, :o1, 1541311200
          tz.transition 2019, 3, :o2, 1552201200
          tz.transition 2019, 11, :o1, 1572760800
          tz.transition 2020, 3, :o2, 1583650800
          tz.transition 2020, 11, :o1, 1604210400
          tz.transition 2021, 3, :o2, 1615705200
          tz.transition 2021, 11, :o1, 1636264800
          tz.transition 2022, 3, :o2, 1647154800
          tz.transition 2022, 11, :o1, 1667714400
          tz.transition 2023, 3, :o2, 1678604400
          tz.transition 2023, 11, :o1, 1699164000
          tz.transition 2024, 3, :o2, 1710054000
          tz.transition 2024, 11, :o1, 1730613600
          tz.transition 2025, 3, :o2, 1741503600
          tz.transition 2025, 11, :o1, 1762063200
          tz.transition 2026, 3, :o2, 1772953200
          tz.transition 2026, 11, :o1, 1793512800
          tz.transition 2027, 3, :o2, 1805007600
          tz.transition 2027, 11, :o1, 1825567200
          tz.transition 2028, 3, :o2, 1836457200
          tz.transition 2028, 11, :o1, 1857016800
          tz.transition 2029, 3, :o2, 1867906800
          tz.transition 2029, 11, :o1, 1888466400
          tz.transition 2030, 3, :o2, 1899356400
          tz.transition 2030, 11, :o1, 1919916000
          tz.transition 2031, 3, :o2, 1930806000
          tz.transition 2031, 11, :o1, 1951365600
          tz.transition 2032, 3, :o2, 1962860400
          tz.transition 2032, 11, :o1, 1983420000
          tz.transition 2033, 3, :o2, 1994310000
          tz.transition 2033, 11, :o1, 2014869600
          tz.transition 2034, 3, :o2, 2025759600
          tz.transition 2034, 11, :o1, 2046319200
          tz.transition 2035, 3, :o2, 2057209200
          tz.transition 2035, 11, :o1, 2077768800
          tz.transition 2036, 3, :o2, 2088658800
          tz.transition 2036, 11, :o1, 2109218400
          tz.transition 2037, 3, :o2, 2120108400
          tz.transition 2037, 11, :o1, 2140668000
          tz.transition 2038, 3, :o2, 59171923, 24
          tz.transition 2038, 11, :o1, 9862939, 4
          tz.transition 2039, 3, :o2, 59180659, 24
          tz.transition 2039, 11, :o1, 9864395, 4
          tz.transition 2040, 3, :o2, 59189395, 24
          tz.transition 2040, 11, :o1, 9865851, 4
          tz.transition 2041, 3, :o2, 59198131, 24
          tz.transition 2041, 11, :o1, 9867307, 4
          tz.transition 2042, 3, :o2, 59206867, 24
          tz.transition 2042, 11, :o1, 9868763, 4
          tz.transition 2043, 3, :o2, 59215603, 24
          tz.transition 2043, 11, :o1, 9870219, 4
          tz.transition 2044, 3, :o2, 59224507, 24
          tz.transition 2044, 11, :o1, 9871703, 4
          tz.transition 2045, 3, :o2, 59233243, 24
          tz.transition 2045, 11, :o1, 9873159, 4
          tz.transition 2046, 3, :o2, 59241979, 24
          tz.transition 2046, 11, :o1, 9874615, 4
          tz.transition 2047, 3, :o2, 59250715, 24
          tz.transition 2047, 11, :o1, 9876071, 4
          tz.transition 2048, 3, :o2, 59259451, 24
          tz.transition 2048, 11, :o1, 9877527, 4
          tz.transition 2049, 3, :o2, 59268355, 24
          tz.transition 2049, 11, :o1, 9879011, 4
          tz.transition 2050, 3, :o2, 59277091, 24
          tz.transition 2050, 11, :o1, 9880467, 4
        end
      end
    end
  end
end
