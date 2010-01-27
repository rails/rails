require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Jerusalem
        include TimezoneDefinition
        
        timezone 'Asia/Jerusalem' do |tz|
          tz.offset :o0, 8456, 0, :LMT
          tz.offset :o1, 8440, 0, :JMT
          tz.offset :o2, 7200, 0, :IST
          tz.offset :o3, 7200, 3600, :IDT
          tz.offset :o4, 7200, 7200, :IDDT
          
          tz.transition 1879, 12, :o1, 26003326343, 10800
          tz.transition 1917, 12, :o2, 5230643909, 2160
          tz.transition 1940, 5, :o3, 29157377, 12
          tz.transition 1942, 10, :o2, 19445315, 8
          tz.transition 1943, 4, :o3, 4861631, 2
          tz.transition 1943, 10, :o2, 19448235, 8
          tz.transition 1944, 3, :o3, 29174177, 12
          tz.transition 1944, 10, :o2, 19451163, 8
          tz.transition 1945, 4, :o3, 29178737, 12
          tz.transition 1945, 10, :o2, 58362251, 24
          tz.transition 1946, 4, :o3, 4863853, 2
          tz.transition 1946, 10, :o2, 19457003, 8
          tz.transition 1948, 5, :o4, 29192333, 12
          tz.transition 1948, 8, :o3, 7298386, 3
          tz.transition 1948, 10, :o2, 58388555, 24
          tz.transition 1949, 4, :o3, 29196449, 12
          tz.transition 1949, 10, :o2, 58397315, 24
          tz.transition 1950, 4, :o3, 29200649, 12
          tz.transition 1950, 9, :o2, 4867079, 2
          tz.transition 1951, 3, :o3, 29204849, 12
          tz.transition 1951, 11, :o2, 4867923, 2
          tz.transition 1952, 4, :o3, 4868245, 2
          tz.transition 1952, 10, :o2, 4868609, 2
          tz.transition 1953, 4, :o3, 4868959, 2
          tz.transition 1953, 9, :o2, 4869267, 2
          tz.transition 1954, 6, :o3, 29218877, 12
          tz.transition 1954, 9, :o2, 19479979, 8
          tz.transition 1955, 6, :o3, 4870539, 2
          tz.transition 1955, 9, :o2, 19482891, 8
          tz.transition 1956, 6, :o3, 29227529, 12
          tz.transition 1956, 9, :o2, 4871493, 2
          tz.transition 1957, 4, :o3, 4871915, 2
          tz.transition 1957, 9, :o2, 19488827, 8
          tz.transition 1974, 7, :o3, 142380000
          tz.transition 1974, 10, :o2, 150843600
          tz.transition 1975, 4, :o3, 167176800
          tz.transition 1975, 8, :o2, 178664400
          tz.transition 1985, 4, :o3, 482277600
          tz.transition 1985, 9, :o2, 495579600
          tz.transition 1986, 5, :o3, 516751200
          tz.transition 1986, 9, :o2, 526424400
          tz.transition 1987, 4, :o3, 545436000
          tz.transition 1987, 9, :o2, 558478800
          tz.transition 1988, 4, :o3, 576540000
          tz.transition 1988, 9, :o2, 589237200
          tz.transition 1989, 4, :o3, 609890400
          tz.transition 1989, 9, :o2, 620773200
          tz.transition 1990, 3, :o3, 638316000
          tz.transition 1990, 8, :o2, 651618000
          tz.transition 1991, 3, :o3, 669765600
          tz.transition 1991, 8, :o2, 683672400
          tz.transition 1992, 3, :o3, 701820000
          tz.transition 1992, 9, :o2, 715726800
          tz.transition 1993, 4, :o3, 733701600
          tz.transition 1993, 9, :o2, 747176400
          tz.transition 1994, 3, :o3, 765151200
          tz.transition 1994, 8, :o2, 778021200
          tz.transition 1995, 3, :o3, 796600800
          tz.transition 1995, 9, :o2, 810075600
          tz.transition 1996, 3, :o3, 826840800
          tz.transition 1996, 9, :o2, 842821200
          tz.transition 1997, 3, :o3, 858895200
          tz.transition 1997, 9, :o2, 874184400
          tz.transition 1998, 3, :o3, 890344800
          tz.transition 1998, 9, :o2, 905029200
          tz.transition 1999, 4, :o3, 923011200
          tz.transition 1999, 9, :o2, 936313200
          tz.transition 2000, 4, :o3, 955670400
          tz.transition 2000, 10, :o2, 970783200
          tz.transition 2001, 4, :o3, 986770800
          tz.transition 2001, 9, :o2, 1001282400
          tz.transition 2002, 3, :o3, 1017356400
          tz.transition 2002, 10, :o2, 1033941600
          tz.transition 2003, 3, :o3, 1048806000
          tz.transition 2003, 10, :o2, 1065132000
          tz.transition 2004, 4, :o3, 1081292400
          tz.transition 2004, 9, :o2, 1095804000
          tz.transition 2005, 4, :o3, 1112313600
          tz.transition 2005, 10, :o2, 1128812400
          tz.transition 2006, 3, :o3, 1143763200
          tz.transition 2006, 9, :o2, 1159657200
          tz.transition 2007, 3, :o3, 1175212800
          tz.transition 2007, 9, :o2, 1189897200
          tz.transition 2008, 3, :o3, 1206662400
          tz.transition 2008, 10, :o2, 1223161200
          tz.transition 2009, 3, :o3, 1238112000
          tz.transition 2009, 9, :o2, 1254006000
          tz.transition 2010, 3, :o3, 1269561600
          tz.transition 2010, 9, :o2, 1284246000
          tz.transition 2011, 4, :o3, 1301616000
          tz.transition 2011, 10, :o2, 1317510000
          tz.transition 2012, 3, :o3, 1333065600
          tz.transition 2012, 9, :o2, 1348354800
          tz.transition 2013, 3, :o3, 1364515200
          tz.transition 2013, 9, :o2, 1378594800
          tz.transition 2014, 3, :o3, 1395964800
          tz.transition 2014, 9, :o2, 1411858800
          tz.transition 2015, 3, :o3, 1427414400
          tz.transition 2015, 9, :o2, 1442703600
          tz.transition 2016, 4, :o3, 1459468800
          tz.transition 2016, 10, :o2, 1475967600
          tz.transition 2017, 3, :o3, 1490918400
          tz.transition 2017, 9, :o2, 1506207600
          tz.transition 2018, 3, :o3, 1522368000
          tz.transition 2018, 9, :o2, 1537052400
          tz.transition 2019, 3, :o3, 1553817600
          tz.transition 2019, 10, :o2, 1570316400
          tz.transition 2020, 3, :o3, 1585267200
          tz.transition 2020, 9, :o2, 1601161200
          tz.transition 2021, 3, :o3, 1616716800
          tz.transition 2021, 9, :o2, 1631401200
          tz.transition 2022, 4, :o3, 1648771200
          tz.transition 2022, 10, :o2, 1664665200
          tz.transition 2023, 3, :o3, 1680220800
          tz.transition 2023, 9, :o2, 1695510000
          tz.transition 2024, 3, :o3, 1711670400
          tz.transition 2024, 10, :o2, 1728169200
          tz.transition 2025, 3, :o3, 1743120000
          tz.transition 2025, 9, :o2, 1759014000
          tz.transition 2026, 3, :o3, 1774569600
          tz.transition 2026, 9, :o2, 1789858800
          tz.transition 2027, 3, :o3, 1806019200
          tz.transition 2027, 10, :o2, 1823122800
          tz.transition 2028, 3, :o3, 1838073600
          tz.transition 2028, 9, :o2, 1853362800
          tz.transition 2029, 3, :o3, 1869523200
          tz.transition 2029, 9, :o2, 1884207600
          tz.transition 2030, 3, :o3, 1900972800
          tz.transition 2030, 10, :o2, 1917471600
          tz.transition 2031, 3, :o3, 1932422400
          tz.transition 2031, 9, :o2, 1947711600
          tz.transition 2032, 3, :o3, 1963872000
          tz.transition 2032, 9, :o2, 1978556400
          tz.transition 2033, 4, :o3, 1995926400
          tz.transition 2033, 10, :o2, 2011820400
          tz.transition 2034, 3, :o3, 2027376000
          tz.transition 2034, 9, :o2, 2042060400
          tz.transition 2035, 3, :o3, 2058825600
          tz.transition 2035, 10, :o2, 2075324400
          tz.transition 2036, 3, :o3, 2090275200
          tz.transition 2036, 9, :o2, 2106169200
          tz.transition 2037, 3, :o3, 2121724800
          tz.transition 2037, 9, :o2, 2136409200
        end
      end
    end
  end
end
