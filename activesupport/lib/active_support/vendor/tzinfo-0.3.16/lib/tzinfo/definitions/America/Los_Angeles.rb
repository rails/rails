require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module America
      module Los_Angeles
        include TimezoneDefinition
        
        timezone 'America/Los_Angeles' do |tz|
          tz.offset :o0, -28378, 0, :LMT
          tz.offset :o1, -28800, 0, :PST
          tz.offset :o2, -28800, 3600, :PDT
          tz.offset :o3, -28800, 3600, :PWT
          tz.offset :o4, -28800, 3600, :PPT
          
          tz.transition 1883, 11, :o1, 7227400, 3
          tz.transition 1918, 3, :o2, 29060207, 12
          tz.transition 1918, 10, :o1, 19375151, 8
          tz.transition 1919, 3, :o2, 29064575, 12
          tz.transition 1919, 10, :o1, 19378063, 8
          tz.transition 1942, 2, :o3, 29164799, 12
          tz.transition 1945, 8, :o4, 58360379, 24
          tz.transition 1945, 9, :o1, 19453831, 8
          tz.transition 1948, 3, :o2, 29191499, 12
          tz.transition 1949, 1, :o1, 19463343, 8
          tz.transition 1950, 4, :o2, 29200823, 12
          tz.transition 1950, 9, :o1, 19468391, 8
          tz.transition 1951, 4, :o2, 29205191, 12
          tz.transition 1951, 9, :o1, 19471359, 8
          tz.transition 1952, 4, :o2, 29209559, 12
          tz.transition 1952, 9, :o1, 19474271, 8
          tz.transition 1953, 4, :o2, 29213927, 12
          tz.transition 1953, 9, :o1, 19477183, 8
          tz.transition 1954, 4, :o2, 29218295, 12
          tz.transition 1954, 9, :o1, 19480095, 8
          tz.transition 1955, 4, :o2, 29222663, 12
          tz.transition 1955, 9, :o1, 19483007, 8
          tz.transition 1956, 4, :o2, 29227115, 12
          tz.transition 1956, 9, :o1, 19485975, 8
          tz.transition 1957, 4, :o2, 29231483, 12
          tz.transition 1957, 9, :o1, 19488887, 8
          tz.transition 1958, 4, :o2, 29235851, 12
          tz.transition 1958, 9, :o1, 19491799, 8
          tz.transition 1959, 4, :o2, 29240219, 12
          tz.transition 1959, 9, :o1, 19494711, 8
          tz.transition 1960, 4, :o2, 29244587, 12
          tz.transition 1960, 9, :o1, 19497623, 8
          tz.transition 1961, 4, :o2, 29249039, 12
          tz.transition 1961, 9, :o1, 19500535, 8
          tz.transition 1962, 4, :o2, 29253407, 12
          tz.transition 1962, 10, :o1, 19503727, 8
          tz.transition 1963, 4, :o2, 29257775, 12
          tz.transition 1963, 10, :o1, 19506639, 8
          tz.transition 1964, 4, :o2, 29262143, 12
          tz.transition 1964, 10, :o1, 19509551, 8
          tz.transition 1965, 4, :o2, 29266511, 12
          tz.transition 1965, 10, :o1, 19512519, 8
          tz.transition 1966, 4, :o2, 29270879, 12
          tz.transition 1966, 10, :o1, 19515431, 8
          tz.transition 1967, 4, :o2, 29275331, 12
          tz.transition 1967, 10, :o1, 19518343, 8
          tz.transition 1968, 4, :o2, 29279699, 12
          tz.transition 1968, 10, :o1, 19521255, 8
          tz.transition 1969, 4, :o2, 29284067, 12
          tz.transition 1969, 10, :o1, 19524167, 8
          tz.transition 1970, 4, :o2, 9972000
          tz.transition 1970, 10, :o1, 25693200
          tz.transition 1971, 4, :o2, 41421600
          tz.transition 1971, 10, :o1, 57747600
          tz.transition 1972, 4, :o2, 73476000
          tz.transition 1972, 10, :o1, 89197200
          tz.transition 1973, 4, :o2, 104925600
          tz.transition 1973, 10, :o1, 120646800
          tz.transition 1974, 1, :o2, 126698400
          tz.transition 1974, 10, :o1, 152096400
          tz.transition 1975, 2, :o2, 162381600
          tz.transition 1975, 10, :o1, 183546000
          tz.transition 1976, 4, :o2, 199274400
          tz.transition 1976, 10, :o1, 215600400
          tz.transition 1977, 4, :o2, 230724000
          tz.transition 1977, 10, :o1, 247050000
          tz.transition 1978, 4, :o2, 262778400
          tz.transition 1978, 10, :o1, 278499600
          tz.transition 1979, 4, :o2, 294228000
          tz.transition 1979, 10, :o1, 309949200
          tz.transition 1980, 4, :o2, 325677600
          tz.transition 1980, 10, :o1, 341398800
          tz.transition 1981, 4, :o2, 357127200
          tz.transition 1981, 10, :o1, 372848400
          tz.transition 1982, 4, :o2, 388576800
          tz.transition 1982, 10, :o1, 404902800
          tz.transition 1983, 4, :o2, 420026400
          tz.transition 1983, 10, :o1, 436352400
          tz.transition 1984, 4, :o2, 452080800
          tz.transition 1984, 10, :o1, 467802000
          tz.transition 1985, 4, :o2, 483530400
          tz.transition 1985, 10, :o1, 499251600
          tz.transition 1986, 4, :o2, 514980000
          tz.transition 1986, 10, :o1, 530701200
          tz.transition 1987, 4, :o2, 544615200
          tz.transition 1987, 10, :o1, 562150800
          tz.transition 1988, 4, :o2, 576064800
          tz.transition 1988, 10, :o1, 594205200
          tz.transition 1989, 4, :o2, 607514400
          tz.transition 1989, 10, :o1, 625654800
          tz.transition 1990, 4, :o2, 638964000
          tz.transition 1990, 10, :o1, 657104400
          tz.transition 1991, 4, :o2, 671018400
          tz.transition 1991, 10, :o1, 688554000
          tz.transition 1992, 4, :o2, 702468000
          tz.transition 1992, 10, :o1, 720003600
          tz.transition 1993, 4, :o2, 733917600
          tz.transition 1993, 10, :o1, 752058000
          tz.transition 1994, 4, :o2, 765367200
          tz.transition 1994, 10, :o1, 783507600
          tz.transition 1995, 4, :o2, 796816800
          tz.transition 1995, 10, :o1, 814957200
          tz.transition 1996, 4, :o2, 828871200
          tz.transition 1996, 10, :o1, 846406800
          tz.transition 1997, 4, :o2, 860320800
          tz.transition 1997, 10, :o1, 877856400
          tz.transition 1998, 4, :o2, 891770400
          tz.transition 1998, 10, :o1, 909306000
          tz.transition 1999, 4, :o2, 923220000
          tz.transition 1999, 10, :o1, 941360400
          tz.transition 2000, 4, :o2, 954669600
          tz.transition 2000, 10, :o1, 972810000
          tz.transition 2001, 4, :o2, 986119200
          tz.transition 2001, 10, :o1, 1004259600
          tz.transition 2002, 4, :o2, 1018173600
          tz.transition 2002, 10, :o1, 1035709200
          tz.transition 2003, 4, :o2, 1049623200
          tz.transition 2003, 10, :o1, 1067158800
          tz.transition 2004, 4, :o2, 1081072800
          tz.transition 2004, 10, :o1, 1099213200
          tz.transition 2005, 4, :o2, 1112522400
          tz.transition 2005, 10, :o1, 1130662800
          tz.transition 2006, 4, :o2, 1143972000
          tz.transition 2006, 10, :o1, 1162112400
          tz.transition 2007, 3, :o2, 1173607200
          tz.transition 2007, 11, :o1, 1194166800
          tz.transition 2008, 3, :o2, 1205056800
          tz.transition 2008, 11, :o1, 1225616400
          tz.transition 2009, 3, :o2, 1236506400
          tz.transition 2009, 11, :o1, 1257066000
          tz.transition 2010, 3, :o2, 1268560800
          tz.transition 2010, 11, :o1, 1289120400
          tz.transition 2011, 3, :o2, 1300010400
          tz.transition 2011, 11, :o1, 1320570000
          tz.transition 2012, 3, :o2, 1331460000
          tz.transition 2012, 11, :o1, 1352019600
          tz.transition 2013, 3, :o2, 1362909600
          tz.transition 2013, 11, :o1, 1383469200
          tz.transition 2014, 3, :o2, 1394359200
          tz.transition 2014, 11, :o1, 1414918800
          tz.transition 2015, 3, :o2, 1425808800
          tz.transition 2015, 11, :o1, 1446368400
          tz.transition 2016, 3, :o2, 1457863200
          tz.transition 2016, 11, :o1, 1478422800
          tz.transition 2017, 3, :o2, 1489312800
          tz.transition 2017, 11, :o1, 1509872400
          tz.transition 2018, 3, :o2, 1520762400
          tz.transition 2018, 11, :o1, 1541322000
          tz.transition 2019, 3, :o2, 1552212000
          tz.transition 2019, 11, :o1, 1572771600
          tz.transition 2020, 3, :o2, 1583661600
          tz.transition 2020, 11, :o1, 1604221200
          tz.transition 2021, 3, :o2, 1615716000
          tz.transition 2021, 11, :o1, 1636275600
          tz.transition 2022, 3, :o2, 1647165600
          tz.transition 2022, 11, :o1, 1667725200
          tz.transition 2023, 3, :o2, 1678615200
          tz.transition 2023, 11, :o1, 1699174800
          tz.transition 2024, 3, :o2, 1710064800
          tz.transition 2024, 11, :o1, 1730624400
          tz.transition 2025, 3, :o2, 1741514400
          tz.transition 2025, 11, :o1, 1762074000
          tz.transition 2026, 3, :o2, 1772964000
          tz.transition 2026, 11, :o1, 1793523600
          tz.transition 2027, 3, :o2, 1805018400
          tz.transition 2027, 11, :o1, 1825578000
          tz.transition 2028, 3, :o2, 1836468000
          tz.transition 2028, 11, :o1, 1857027600
          tz.transition 2029, 3, :o2, 1867917600
          tz.transition 2029, 11, :o1, 1888477200
          tz.transition 2030, 3, :o2, 1899367200
          tz.transition 2030, 11, :o1, 1919926800
          tz.transition 2031, 3, :o2, 1930816800
          tz.transition 2031, 11, :o1, 1951376400
          tz.transition 2032, 3, :o2, 1962871200
          tz.transition 2032, 11, :o1, 1983430800
          tz.transition 2033, 3, :o2, 1994320800
          tz.transition 2033, 11, :o1, 2014880400
          tz.transition 2034, 3, :o2, 2025770400
          tz.transition 2034, 11, :o1, 2046330000
          tz.transition 2035, 3, :o2, 2057220000
          tz.transition 2035, 11, :o1, 2077779600
          tz.transition 2036, 3, :o2, 2088669600
          tz.transition 2036, 11, :o1, 2109229200
          tz.transition 2037, 3, :o2, 2120119200
          tz.transition 2037, 11, :o1, 2140678800
          tz.transition 2038, 3, :o2, 29585963, 12
          tz.transition 2038, 11, :o1, 19725879, 8
          tz.transition 2039, 3, :o2, 29590331, 12
          tz.transition 2039, 11, :o1, 19728791, 8
          tz.transition 2040, 3, :o2, 29594699, 12
          tz.transition 2040, 11, :o1, 19731703, 8
          tz.transition 2041, 3, :o2, 29599067, 12
          tz.transition 2041, 11, :o1, 19734615, 8
          tz.transition 2042, 3, :o2, 29603435, 12
          tz.transition 2042, 11, :o1, 19737527, 8
          tz.transition 2043, 3, :o2, 29607803, 12
          tz.transition 2043, 11, :o1, 19740439, 8
          tz.transition 2044, 3, :o2, 29612255, 12
          tz.transition 2044, 11, :o1, 19743407, 8
          tz.transition 2045, 3, :o2, 29616623, 12
          tz.transition 2045, 11, :o1, 19746319, 8
          tz.transition 2046, 3, :o2, 29620991, 12
          tz.transition 2046, 11, :o1, 19749231, 8
          tz.transition 2047, 3, :o2, 29625359, 12
          tz.transition 2047, 11, :o1, 19752143, 8
          tz.transition 2048, 3, :o2, 29629727, 12
          tz.transition 2048, 11, :o1, 19755055, 8
          tz.transition 2049, 3, :o2, 29634179, 12
          tz.transition 2049, 11, :o1, 19758023, 8
          tz.transition 2050, 3, :o2, 29638547, 12
          tz.transition 2050, 11, :o1, 19760935, 8
        end
      end
    end
  end
end
