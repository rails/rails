require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Europe
      module Moscow
        include TimezoneDefinition
        
        timezone 'Europe/Moscow' do |tz|
          tz.offset :o0, 9020, 0, :LMT
          tz.offset :o1, 9000, 0, :MMT
          tz.offset :o2, 9048, 0, :MMT
          tz.offset :o3, 9048, 3600, :MST
          tz.offset :o4, 9048, 7200, :MDST
          tz.offset :o5, 10800, 3600, :MSD
          tz.offset :o6, 10800, 0, :MSK
          tz.offset :o7, 10800, 7200, :MSD
          tz.offset :o8, 7200, 0, :EET
          tz.offset :o9, 7200, 3600, :EEST
          
          tz.transition 1879, 12, :o1, 10401330509, 4320
          tz.transition 1916, 7, :o2, 116210275, 48
          tz.transition 1917, 7, :o3, 8717080873, 3600
          tz.transition 1917, 12, :o2, 8717725273, 3600
          tz.transition 1918, 5, :o4, 8718283123, 3600
          tz.transition 1918, 9, :o3, 8718668473, 3600
          tz.transition 1919, 5, :o4, 8719597123, 3600
          tz.transition 1919, 6, :o5, 8719705423, 3600
          tz.transition 1919, 8, :o6, 7266559, 3
          tz.transition 1921, 2, :o5, 7268206, 3
          tz.transition 1921, 3, :o7, 58146463, 24
          tz.transition 1921, 8, :o5, 58150399, 24
          tz.transition 1921, 9, :o6, 7268890, 3
          tz.transition 1922, 9, :o8, 19386627, 8
          tz.transition 1930, 6, :o6, 29113781, 12
          tz.transition 1981, 3, :o5, 354920400
          tz.transition 1981, 9, :o6, 370728000
          tz.transition 1982, 3, :o5, 386456400
          tz.transition 1982, 9, :o6, 402264000
          tz.transition 1983, 3, :o5, 417992400
          tz.transition 1983, 9, :o6, 433800000
          tz.transition 1984, 3, :o5, 449614800
          tz.transition 1984, 9, :o6, 465346800
          tz.transition 1985, 3, :o5, 481071600
          tz.transition 1985, 9, :o6, 496796400
          tz.transition 1986, 3, :o5, 512521200
          tz.transition 1986, 9, :o6, 528246000
          tz.transition 1987, 3, :o5, 543970800
          tz.transition 1987, 9, :o6, 559695600
          tz.transition 1988, 3, :o5, 575420400
          tz.transition 1988, 9, :o6, 591145200
          tz.transition 1989, 3, :o5, 606870000
          tz.transition 1989, 9, :o6, 622594800
          tz.transition 1990, 3, :o5, 638319600
          tz.transition 1990, 9, :o6, 654649200
          tz.transition 1991, 3, :o9, 670374000
          tz.transition 1991, 9, :o8, 686102400
          tz.transition 1992, 1, :o6, 695779200
          tz.transition 1992, 3, :o5, 701812800
          tz.transition 1992, 9, :o6, 717534000
          tz.transition 1993, 3, :o5, 733273200
          tz.transition 1993, 9, :o6, 748998000
          tz.transition 1994, 3, :o5, 764722800
          tz.transition 1994, 9, :o6, 780447600
          tz.transition 1995, 3, :o5, 796172400
          tz.transition 1995, 9, :o6, 811897200
          tz.transition 1996, 3, :o5, 828226800
          tz.transition 1996, 10, :o6, 846370800
          tz.transition 1997, 3, :o5, 859676400
          tz.transition 1997, 10, :o6, 877820400
          tz.transition 1998, 3, :o5, 891126000
          tz.transition 1998, 10, :o6, 909270000
          tz.transition 1999, 3, :o5, 922575600
          tz.transition 1999, 10, :o6, 941324400
          tz.transition 2000, 3, :o5, 954025200
          tz.transition 2000, 10, :o6, 972774000
          tz.transition 2001, 3, :o5, 985474800
          tz.transition 2001, 10, :o6, 1004223600
          tz.transition 2002, 3, :o5, 1017529200
          tz.transition 2002, 10, :o6, 1035673200
          tz.transition 2003, 3, :o5, 1048978800
          tz.transition 2003, 10, :o6, 1067122800
          tz.transition 2004, 3, :o5, 1080428400
          tz.transition 2004, 10, :o6, 1099177200
          tz.transition 2005, 3, :o5, 1111878000
          tz.transition 2005, 10, :o6, 1130626800
          tz.transition 2006, 3, :o5, 1143327600
          tz.transition 2006, 10, :o6, 1162076400
          tz.transition 2007, 3, :o5, 1174777200
          tz.transition 2007, 10, :o6, 1193526000
          tz.transition 2008, 3, :o5, 1206831600
          tz.transition 2008, 10, :o6, 1224975600
          tz.transition 2009, 3, :o5, 1238281200
          tz.transition 2009, 10, :o6, 1256425200
          tz.transition 2010, 3, :o5, 1269730800
          tz.transition 2010, 10, :o6, 1288479600
          tz.transition 2011, 3, :o5, 1301180400
          tz.transition 2011, 10, :o6, 1319929200
          tz.transition 2012, 3, :o5, 1332630000
          tz.transition 2012, 10, :o6, 1351378800
          tz.transition 2013, 3, :o5, 1364684400
          tz.transition 2013, 10, :o6, 1382828400
          tz.transition 2014, 3, :o5, 1396134000
          tz.transition 2014, 10, :o6, 1414278000
          tz.transition 2015, 3, :o5, 1427583600
          tz.transition 2015, 10, :o6, 1445727600
          tz.transition 2016, 3, :o5, 1459033200
          tz.transition 2016, 10, :o6, 1477782000
          tz.transition 2017, 3, :o5, 1490482800
          tz.transition 2017, 10, :o6, 1509231600
          tz.transition 2018, 3, :o5, 1521932400
          tz.transition 2018, 10, :o6, 1540681200
          tz.transition 2019, 3, :o5, 1553986800
          tz.transition 2019, 10, :o6, 1572130800
          tz.transition 2020, 3, :o5, 1585436400
          tz.transition 2020, 10, :o6, 1603580400
          tz.transition 2021, 3, :o5, 1616886000
          tz.transition 2021, 10, :o6, 1635634800
          tz.transition 2022, 3, :o5, 1648335600
          tz.transition 2022, 10, :o6, 1667084400
          tz.transition 2023, 3, :o5, 1679785200
          tz.transition 2023, 10, :o6, 1698534000
          tz.transition 2024, 3, :o5, 1711839600
          tz.transition 2024, 10, :o6, 1729983600
          tz.transition 2025, 3, :o5, 1743289200
          tz.transition 2025, 10, :o6, 1761433200
          tz.transition 2026, 3, :o5, 1774738800
          tz.transition 2026, 10, :o6, 1792882800
          tz.transition 2027, 3, :o5, 1806188400
          tz.transition 2027, 10, :o6, 1824937200
          tz.transition 2028, 3, :o5, 1837638000
          tz.transition 2028, 10, :o6, 1856386800
          tz.transition 2029, 3, :o5, 1869087600
          tz.transition 2029, 10, :o6, 1887836400
          tz.transition 2030, 3, :o5, 1901142000
          tz.transition 2030, 10, :o6, 1919286000
          tz.transition 2031, 3, :o5, 1932591600
          tz.transition 2031, 10, :o6, 1950735600
          tz.transition 2032, 3, :o5, 1964041200
          tz.transition 2032, 10, :o6, 1982790000
          tz.transition 2033, 3, :o5, 1995490800
          tz.transition 2033, 10, :o6, 2014239600
          tz.transition 2034, 3, :o5, 2026940400
          tz.transition 2034, 10, :o6, 2045689200
          tz.transition 2035, 3, :o5, 2058390000
          tz.transition 2035, 10, :o6, 2077138800
          tz.transition 2036, 3, :o5, 2090444400
          tz.transition 2036, 10, :o6, 2108588400
          tz.transition 2037, 3, :o5, 2121894000
          tz.transition 2037, 10, :o6, 2140038000
          tz.transition 2038, 3, :o5, 59172251, 24
          tz.transition 2038, 10, :o6, 59177459, 24
          tz.transition 2039, 3, :o5, 59180987, 24
          tz.transition 2039, 10, :o6, 59186195, 24
          tz.transition 2040, 3, :o5, 59189723, 24
          tz.transition 2040, 10, :o6, 59194931, 24
          tz.transition 2041, 3, :o5, 59198627, 24
          tz.transition 2041, 10, :o6, 59203667, 24
          tz.transition 2042, 3, :o5, 59207363, 24
          tz.transition 2042, 10, :o6, 59212403, 24
          tz.transition 2043, 3, :o5, 59216099, 24
          tz.transition 2043, 10, :o6, 59221139, 24
          tz.transition 2044, 3, :o5, 59224835, 24
          tz.transition 2044, 10, :o6, 59230043, 24
          tz.transition 2045, 3, :o5, 59233571, 24
          tz.transition 2045, 10, :o6, 59238779, 24
          tz.transition 2046, 3, :o5, 59242307, 24
          tz.transition 2046, 10, :o6, 59247515, 24
          tz.transition 2047, 3, :o5, 59251211, 24
          tz.transition 2047, 10, :o6, 59256251, 24
          tz.transition 2048, 3, :o5, 59259947, 24
          tz.transition 2048, 10, :o6, 59264987, 24
          tz.transition 2049, 3, :o5, 59268683, 24
          tz.transition 2049, 10, :o6, 59273891, 24
          tz.transition 2050, 3, :o5, 59277419, 24
          tz.transition 2050, 10, :o6, 59282627, 24
        end
      end
    end
  end
end
