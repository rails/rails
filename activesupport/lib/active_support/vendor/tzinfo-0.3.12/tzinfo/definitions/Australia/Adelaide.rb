require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Australia
      module Adelaide
        include TimezoneDefinition
        
        timezone 'Australia/Adelaide' do |tz|
          tz.offset :o0, 33260, 0, :LMT
          tz.offset :o1, 32400, 0, :CST
          tz.offset :o2, 34200, 0, :CST
          tz.offset :o3, 34200, 3600, :CST
          
          tz.transition 1895, 1, :o1, 10425132497, 4320
          tz.transition 1899, 4, :o2, 19318201, 8
          tz.transition 1916, 12, :o3, 3486569911, 1440
          tz.transition 1917, 3, :o2, 116222983, 48
          tz.transition 1941, 12, :o3, 38885763, 16
          tz.transition 1942, 3, :o2, 116661463, 48
          tz.transition 1942, 9, :o3, 38890067, 16
          tz.transition 1943, 3, :o2, 116678935, 48
          tz.transition 1943, 10, :o3, 38896003, 16
          tz.transition 1944, 3, :o2, 116696407, 48
          tz.transition 1971, 10, :o3, 57688200
          tz.transition 1972, 2, :o2, 67969800
          tz.transition 1972, 10, :o3, 89137800
          tz.transition 1973, 3, :o2, 100024200
          tz.transition 1973, 10, :o3, 120587400
          tz.transition 1974, 3, :o2, 131473800
          tz.transition 1974, 10, :o3, 152037000
          tz.transition 1975, 3, :o2, 162923400
          tz.transition 1975, 10, :o3, 183486600
          tz.transition 1976, 3, :o2, 194977800
          tz.transition 1976, 10, :o3, 215541000
          tz.transition 1977, 3, :o2, 226427400
          tz.transition 1977, 10, :o3, 246990600
          tz.transition 1978, 3, :o2, 257877000
          tz.transition 1978, 10, :o3, 278440200
          tz.transition 1979, 3, :o2, 289326600
          tz.transition 1979, 10, :o3, 309889800
          tz.transition 1980, 3, :o2, 320776200
          tz.transition 1980, 10, :o3, 341339400
          tz.transition 1981, 2, :o2, 352225800
          tz.transition 1981, 10, :o3, 372789000
          tz.transition 1982, 3, :o2, 384280200
          tz.transition 1982, 10, :o3, 404843400
          tz.transition 1983, 3, :o2, 415729800
          tz.transition 1983, 10, :o3, 436293000
          tz.transition 1984, 3, :o2, 447179400
          tz.transition 1984, 10, :o3, 467742600
          tz.transition 1985, 3, :o2, 478629000
          tz.transition 1985, 10, :o3, 499192200
          tz.transition 1986, 3, :o2, 511288200
          tz.transition 1986, 10, :o3, 530037000
          tz.transition 1987, 3, :o2, 542737800
          tz.transition 1987, 10, :o3, 562091400
          tz.transition 1988, 3, :o2, 574792200
          tz.transition 1988, 10, :o3, 594145800
          tz.transition 1989, 3, :o2, 606241800
          tz.transition 1989, 10, :o3, 625595400
          tz.transition 1990, 3, :o2, 637691400
          tz.transition 1990, 10, :o3, 657045000
          tz.transition 1991, 3, :o2, 667931400
          tz.transition 1991, 10, :o3, 688494600
          tz.transition 1992, 3, :o2, 701195400
          tz.transition 1992, 10, :o3, 719944200
          tz.transition 1993, 3, :o2, 731435400
          tz.transition 1993, 10, :o3, 751998600
          tz.transition 1994, 3, :o2, 764094600
          tz.transition 1994, 10, :o3, 783448200
          tz.transition 1995, 3, :o2, 796149000
          tz.transition 1995, 10, :o3, 814897800
          tz.transition 1996, 3, :o2, 828203400
          tz.transition 1996, 10, :o3, 846347400
          tz.transition 1997, 3, :o2, 859653000
          tz.transition 1997, 10, :o3, 877797000
          tz.transition 1998, 3, :o2, 891102600
          tz.transition 1998, 10, :o3, 909246600
          tz.transition 1999, 3, :o2, 922552200
          tz.transition 1999, 10, :o3, 941301000
          tz.transition 2000, 3, :o2, 954001800
          tz.transition 2000, 10, :o3, 972750600
          tz.transition 2001, 3, :o2, 985451400
          tz.transition 2001, 10, :o3, 1004200200
          tz.transition 2002, 3, :o2, 1017505800
          tz.transition 2002, 10, :o3, 1035649800
          tz.transition 2003, 3, :o2, 1048955400
          tz.transition 2003, 10, :o3, 1067099400
          tz.transition 2004, 3, :o2, 1080405000
          tz.transition 2004, 10, :o3, 1099153800
          tz.transition 2005, 3, :o2, 1111854600
          tz.transition 2005, 10, :o3, 1130603400
          tz.transition 2006, 4, :o2, 1143909000
          tz.transition 2006, 10, :o3, 1162053000
          tz.transition 2007, 3, :o2, 1174753800
          tz.transition 2007, 10, :o3, 1193502600
          tz.transition 2008, 4, :o2, 1207413000
          tz.transition 2008, 10, :o3, 1223137800
          tz.transition 2009, 4, :o2, 1238862600
          tz.transition 2009, 10, :o3, 1254587400
          tz.transition 2010, 4, :o2, 1270312200
          tz.transition 2010, 10, :o3, 1286037000
          tz.transition 2011, 4, :o2, 1301761800
          tz.transition 2011, 10, :o3, 1317486600
          tz.transition 2012, 3, :o2, 1333211400
          tz.transition 2012, 10, :o3, 1349541000
          tz.transition 2013, 4, :o2, 1365265800
          tz.transition 2013, 10, :o3, 1380990600
          tz.transition 2014, 4, :o2, 1396715400
          tz.transition 2014, 10, :o3, 1412440200
          tz.transition 2015, 4, :o2, 1428165000
          tz.transition 2015, 10, :o3, 1443889800
          tz.transition 2016, 4, :o2, 1459614600
          tz.transition 2016, 10, :o3, 1475339400
          tz.transition 2017, 4, :o2, 1491064200
          tz.transition 2017, 9, :o3, 1506789000
          tz.transition 2018, 3, :o2, 1522513800
          tz.transition 2018, 10, :o3, 1538843400
          tz.transition 2019, 4, :o2, 1554568200
          tz.transition 2019, 10, :o3, 1570293000
          tz.transition 2020, 4, :o2, 1586017800
          tz.transition 2020, 10, :o3, 1601742600
          tz.transition 2021, 4, :o2, 1617467400
          tz.transition 2021, 10, :o3, 1633192200
          tz.transition 2022, 4, :o2, 1648917000
          tz.transition 2022, 10, :o3, 1664641800
          tz.transition 2023, 4, :o2, 1680366600
          tz.transition 2023, 9, :o3, 1696091400
          tz.transition 2024, 4, :o2, 1712421000
          tz.transition 2024, 10, :o3, 1728145800
          tz.transition 2025, 4, :o2, 1743870600
          tz.transition 2025, 10, :o3, 1759595400
          tz.transition 2026, 4, :o2, 1775320200
          tz.transition 2026, 10, :o3, 1791045000
          tz.transition 2027, 4, :o2, 1806769800
          tz.transition 2027, 10, :o3, 1822494600
          tz.transition 2028, 4, :o2, 1838219400
          tz.transition 2028, 9, :o3, 1853944200
          tz.transition 2029, 3, :o2, 1869669000
          tz.transition 2029, 10, :o3, 1885998600
          tz.transition 2030, 4, :o2, 1901723400
          tz.transition 2030, 10, :o3, 1917448200
          tz.transition 2031, 4, :o2, 1933173000
          tz.transition 2031, 10, :o3, 1948897800
          tz.transition 2032, 4, :o2, 1964622600
          tz.transition 2032, 10, :o3, 1980347400
          tz.transition 2033, 4, :o2, 1996072200
          tz.transition 2033, 10, :o3, 2011797000
          tz.transition 2034, 4, :o2, 2027521800
          tz.transition 2034, 9, :o3, 2043246600
          tz.transition 2035, 3, :o2, 2058971400
          tz.transition 2035, 10, :o3, 2075301000
          tz.transition 2036, 4, :o2, 2091025800
          tz.transition 2036, 10, :o3, 2106750600
          tz.transition 2037, 4, :o2, 2122475400
          tz.transition 2037, 10, :o3, 2138200200
          tz.transition 2038, 4, :o2, 39448275, 16
          tz.transition 2038, 10, :o3, 39451187, 16
          tz.transition 2039, 4, :o2, 39454099, 16
          tz.transition 2039, 10, :o3, 39457011, 16
          tz.transition 2040, 3, :o2, 39459923, 16
          tz.transition 2040, 10, :o3, 39462947, 16
          tz.transition 2041, 4, :o2, 39465859, 16
          tz.transition 2041, 10, :o3, 39468771, 16
          tz.transition 2042, 4, :o2, 39471683, 16
          tz.transition 2042, 10, :o3, 39474595, 16
          tz.transition 2043, 4, :o2, 39477507, 16
          tz.transition 2043, 10, :o3, 39480419, 16
          tz.transition 2044, 4, :o2, 39483331, 16
          tz.transition 2044, 10, :o3, 39486243, 16
          tz.transition 2045, 4, :o2, 39489155, 16
          tz.transition 2045, 9, :o3, 39492067, 16
          tz.transition 2046, 3, :o2, 39494979, 16
          tz.transition 2046, 10, :o3, 39498003, 16
          tz.transition 2047, 4, :o2, 39500915, 16
          tz.transition 2047, 10, :o3, 39503827, 16
          tz.transition 2048, 4, :o2, 39506739, 16
          tz.transition 2048, 10, :o3, 39509651, 16
          tz.transition 2049, 4, :o2, 39512563, 16
          tz.transition 2049, 10, :o3, 39515475, 16
          tz.transition 2050, 4, :o2, 39518387, 16
        end
      end
    end
  end
end
