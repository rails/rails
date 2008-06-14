require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module America
      module Tijuana
        include TimezoneDefinition
        
        timezone 'America/Tijuana' do |tz|
          tz.offset :o0, -28084, 0, :LMT
          tz.offset :o1, -25200, 0, :MST
          tz.offset :o2, -28800, 0, :PST
          tz.offset :o3, -28800, 3600, :PDT
          tz.offset :o4, -28800, 3600, :PWT
          tz.offset :o5, -28800, 3600, :PPT
          
          tz.transition 1922, 1, :o1, 14538335, 6
          tz.transition 1924, 1, :o2, 58170859, 24
          tz.transition 1927, 6, :o1, 58201027, 24
          tz.transition 1930, 11, :o2, 58231099, 24
          tz.transition 1931, 4, :o3, 14558597, 6
          tz.transition 1931, 9, :o2, 58238755, 24
          tz.transition 1942, 4, :o4, 14582843, 6
          tz.transition 1945, 8, :o5, 58360379, 24
          tz.transition 1945, 11, :o2, 58362523, 24
          tz.transition 1948, 4, :o3, 14595881, 6
          tz.transition 1949, 1, :o2, 58390339, 24
          tz.transition 1954, 4, :o3, 29218295, 12
          tz.transition 1954, 9, :o2, 19480095, 8
          tz.transition 1955, 4, :o3, 29222663, 12
          tz.transition 1955, 9, :o2, 19483007, 8
          tz.transition 1956, 4, :o3, 29227115, 12
          tz.transition 1956, 9, :o2, 19485975, 8
          tz.transition 1957, 4, :o3, 29231483, 12
          tz.transition 1957, 9, :o2, 19488887, 8
          tz.transition 1958, 4, :o3, 29235851, 12
          tz.transition 1958, 9, :o2, 19491799, 8
          tz.transition 1959, 4, :o3, 29240219, 12
          tz.transition 1959, 9, :o2, 19494711, 8
          tz.transition 1960, 4, :o3, 29244587, 12
          tz.transition 1960, 9, :o2, 19497623, 8
          tz.transition 1976, 4, :o3, 199274400
          tz.transition 1976, 10, :o2, 215600400
          tz.transition 1977, 4, :o3, 230724000
          tz.transition 1977, 10, :o2, 247050000
          tz.transition 1978, 4, :o3, 262778400
          tz.transition 1978, 10, :o2, 278499600
          tz.transition 1979, 4, :o3, 294228000
          tz.transition 1979, 10, :o2, 309949200
          tz.transition 1980, 4, :o3, 325677600
          tz.transition 1980, 10, :o2, 341398800
          tz.transition 1981, 4, :o3, 357127200
          tz.transition 1981, 10, :o2, 372848400
          tz.transition 1982, 4, :o3, 388576800
          tz.transition 1982, 10, :o2, 404902800
          tz.transition 1983, 4, :o3, 420026400
          tz.transition 1983, 10, :o2, 436352400
          tz.transition 1984, 4, :o3, 452080800
          tz.transition 1984, 10, :o2, 467802000
          tz.transition 1985, 4, :o3, 483530400
          tz.transition 1985, 10, :o2, 499251600
          tz.transition 1986, 4, :o3, 514980000
          tz.transition 1986, 10, :o2, 530701200
          tz.transition 1987, 4, :o3, 544615200
          tz.transition 1987, 10, :o2, 562150800
          tz.transition 1988, 4, :o3, 576064800
          tz.transition 1988, 10, :o2, 594205200
          tz.transition 1989, 4, :o3, 607514400
          tz.transition 1989, 10, :o2, 625654800
          tz.transition 1990, 4, :o3, 638964000
          tz.transition 1990, 10, :o2, 657104400
          tz.transition 1991, 4, :o3, 671018400
          tz.transition 1991, 10, :o2, 688554000
          tz.transition 1992, 4, :o3, 702468000
          tz.transition 1992, 10, :o2, 720003600
          tz.transition 1993, 4, :o3, 733917600
          tz.transition 1993, 10, :o2, 752058000
          tz.transition 1994, 4, :o3, 765367200
          tz.transition 1994, 10, :o2, 783507600
          tz.transition 1995, 4, :o3, 796816800
          tz.transition 1995, 10, :o2, 814957200
          tz.transition 1996, 4, :o3, 828871200
          tz.transition 1996, 10, :o2, 846406800
          tz.transition 1997, 4, :o3, 860320800
          tz.transition 1997, 10, :o2, 877856400
          tz.transition 1998, 4, :o3, 891770400
          tz.transition 1998, 10, :o2, 909306000
          tz.transition 1999, 4, :o3, 923220000
          tz.transition 1999, 10, :o2, 941360400
          tz.transition 2000, 4, :o3, 954669600
          tz.transition 2000, 10, :o2, 972810000
          tz.transition 2001, 4, :o3, 986119200
          tz.transition 2001, 10, :o2, 1004259600
          tz.transition 2002, 4, :o3, 1018173600
          tz.transition 2002, 10, :o2, 1035709200
          tz.transition 2003, 4, :o3, 1049623200
          tz.transition 2003, 10, :o2, 1067158800
          tz.transition 2004, 4, :o3, 1081072800
          tz.transition 2004, 10, :o2, 1099213200
          tz.transition 2005, 4, :o3, 1112522400
          tz.transition 2005, 10, :o2, 1130662800
          tz.transition 2006, 4, :o3, 1143972000
          tz.transition 2006, 10, :o2, 1162112400
          tz.transition 2007, 4, :o3, 1175421600
          tz.transition 2007, 10, :o2, 1193562000
          tz.transition 2008, 4, :o3, 1207476000
          tz.transition 2008, 10, :o2, 1225011600
          tz.transition 2009, 4, :o3, 1238925600
          tz.transition 2009, 10, :o2, 1256461200
          tz.transition 2010, 4, :o3, 1270375200
          tz.transition 2010, 10, :o2, 1288515600
          tz.transition 2011, 4, :o3, 1301824800
          tz.transition 2011, 10, :o2, 1319965200
          tz.transition 2012, 4, :o3, 1333274400
          tz.transition 2012, 10, :o2, 1351414800
          tz.transition 2013, 4, :o3, 1365328800
          tz.transition 2013, 10, :o2, 1382864400
          tz.transition 2014, 4, :o3, 1396778400
          tz.transition 2014, 10, :o2, 1414314000
          tz.transition 2015, 4, :o3, 1428228000
          tz.transition 2015, 10, :o2, 1445763600
          tz.transition 2016, 4, :o3, 1459677600
          tz.transition 2016, 10, :o2, 1477818000
          tz.transition 2017, 4, :o3, 1491127200
          tz.transition 2017, 10, :o2, 1509267600
          tz.transition 2018, 4, :o3, 1522576800
          tz.transition 2018, 10, :o2, 1540717200
          tz.transition 2019, 4, :o3, 1554631200
          tz.transition 2019, 10, :o2, 1572166800
          tz.transition 2020, 4, :o3, 1586080800
          tz.transition 2020, 10, :o2, 1603616400
          tz.transition 2021, 4, :o3, 1617530400
          tz.transition 2021, 10, :o2, 1635670800
          tz.transition 2022, 4, :o3, 1648980000
          tz.transition 2022, 10, :o2, 1667120400
          tz.transition 2023, 4, :o3, 1680429600
          tz.transition 2023, 10, :o2, 1698570000
          tz.transition 2024, 4, :o3, 1712484000
          tz.transition 2024, 10, :o2, 1730019600
          tz.transition 2025, 4, :o3, 1743933600
          tz.transition 2025, 10, :o2, 1761469200
          tz.transition 2026, 4, :o3, 1775383200
          tz.transition 2026, 10, :o2, 1792918800
          tz.transition 2027, 4, :o3, 1806832800
          tz.transition 2027, 10, :o2, 1824973200
          tz.transition 2028, 4, :o3, 1838282400
          tz.transition 2028, 10, :o2, 1856422800
          tz.transition 2029, 4, :o3, 1869732000
          tz.transition 2029, 10, :o2, 1887872400
          tz.transition 2030, 4, :o3, 1901786400
          tz.transition 2030, 10, :o2, 1919322000
          tz.transition 2031, 4, :o3, 1933236000
          tz.transition 2031, 10, :o2, 1950771600
          tz.transition 2032, 4, :o3, 1964685600
          tz.transition 2032, 10, :o2, 1982826000
          tz.transition 2033, 4, :o3, 1996135200
          tz.transition 2033, 10, :o2, 2014275600
          tz.transition 2034, 4, :o3, 2027584800
          tz.transition 2034, 10, :o2, 2045725200
          tz.transition 2035, 4, :o3, 2059034400
          tz.transition 2035, 10, :o2, 2077174800
          tz.transition 2036, 4, :o3, 2091088800
          tz.transition 2036, 10, :o2, 2108624400
          tz.transition 2037, 4, :o3, 2122538400
          tz.transition 2037, 10, :o2, 2140074000
          tz.transition 2038, 4, :o3, 29586215, 12
          tz.transition 2038, 10, :o2, 19725823, 8
          tz.transition 2039, 4, :o3, 29590583, 12
          tz.transition 2039, 10, :o2, 19728735, 8
          tz.transition 2040, 4, :o3, 29594951, 12
          tz.transition 2040, 10, :o2, 19731647, 8
          tz.transition 2041, 4, :o3, 29599403, 12
          tz.transition 2041, 10, :o2, 19734559, 8
          tz.transition 2042, 4, :o3, 29603771, 12
          tz.transition 2042, 10, :o2, 19737471, 8
          tz.transition 2043, 4, :o3, 29608139, 12
          tz.transition 2043, 10, :o2, 19740383, 8
          tz.transition 2044, 4, :o3, 29612507, 12
          tz.transition 2044, 10, :o2, 19743351, 8
          tz.transition 2045, 4, :o3, 29616875, 12
          tz.transition 2045, 10, :o2, 19746263, 8
          tz.transition 2046, 4, :o3, 29621243, 12
          tz.transition 2046, 10, :o2, 19749175, 8
          tz.transition 2047, 4, :o3, 29625695, 12
          tz.transition 2047, 10, :o2, 19752087, 8
          tz.transition 2048, 4, :o3, 29630063, 12
          tz.transition 2048, 10, :o2, 19754999, 8
          tz.transition 2049, 4, :o3, 29634431, 12
          tz.transition 2049, 10, :o2, 19757967, 8
          tz.transition 2050, 4, :o3, 29638799, 12
          tz.transition 2050, 10, :o2, 19760879, 8
        end
      end
    end
  end
end
