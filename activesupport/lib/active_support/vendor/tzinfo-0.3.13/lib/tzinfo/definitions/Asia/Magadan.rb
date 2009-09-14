require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Magadan
        include TimezoneDefinition
        
        timezone 'Asia/Magadan' do |tz|
          tz.offset :o0, 36192, 0, :LMT
          tz.offset :o1, 36000, 0, :MAGT
          tz.offset :o2, 39600, 0, :MAGT
          tz.offset :o3, 39600, 3600, :MAGST
          tz.offset :o4, 36000, 3600, :MAGST
          
          tz.transition 1924, 5, :o1, 2181516373, 900
          tz.transition 1930, 6, :o2, 29113777, 12
          tz.transition 1981, 3, :o3, 354891600
          tz.transition 1981, 9, :o2, 370699200
          tz.transition 1982, 3, :o3, 386427600
          tz.transition 1982, 9, :o2, 402235200
          tz.transition 1983, 3, :o3, 417963600
          tz.transition 1983, 9, :o2, 433771200
          tz.transition 1984, 3, :o3, 449586000
          tz.transition 1984, 9, :o2, 465318000
          tz.transition 1985, 3, :o3, 481042800
          tz.transition 1985, 9, :o2, 496767600
          tz.transition 1986, 3, :o3, 512492400
          tz.transition 1986, 9, :o2, 528217200
          tz.transition 1987, 3, :o3, 543942000
          tz.transition 1987, 9, :o2, 559666800
          tz.transition 1988, 3, :o3, 575391600
          tz.transition 1988, 9, :o2, 591116400
          tz.transition 1989, 3, :o3, 606841200
          tz.transition 1989, 9, :o2, 622566000
          tz.transition 1990, 3, :o3, 638290800
          tz.transition 1990, 9, :o2, 654620400
          tz.transition 1991, 3, :o4, 670345200
          tz.transition 1991, 9, :o1, 686073600
          tz.transition 1992, 1, :o2, 695750400
          tz.transition 1992, 3, :o3, 701784000
          tz.transition 1992, 9, :o2, 717505200
          tz.transition 1993, 3, :o3, 733244400
          tz.transition 1993, 9, :o2, 748969200
          tz.transition 1994, 3, :o3, 764694000
          tz.transition 1994, 9, :o2, 780418800
          tz.transition 1995, 3, :o3, 796143600
          tz.transition 1995, 9, :o2, 811868400
          tz.transition 1996, 3, :o3, 828198000
          tz.transition 1996, 10, :o2, 846342000
          tz.transition 1997, 3, :o3, 859647600
          tz.transition 1997, 10, :o2, 877791600
          tz.transition 1998, 3, :o3, 891097200
          tz.transition 1998, 10, :o2, 909241200
          tz.transition 1999, 3, :o3, 922546800
          tz.transition 1999, 10, :o2, 941295600
          tz.transition 2000, 3, :o3, 953996400
          tz.transition 2000, 10, :o2, 972745200
          tz.transition 2001, 3, :o3, 985446000
          tz.transition 2001, 10, :o2, 1004194800
          tz.transition 2002, 3, :o3, 1017500400
          tz.transition 2002, 10, :o2, 1035644400
          tz.transition 2003, 3, :o3, 1048950000
          tz.transition 2003, 10, :o2, 1067094000
          tz.transition 2004, 3, :o3, 1080399600
          tz.transition 2004, 10, :o2, 1099148400
          tz.transition 2005, 3, :o3, 1111849200
          tz.transition 2005, 10, :o2, 1130598000
          tz.transition 2006, 3, :o3, 1143298800
          tz.transition 2006, 10, :o2, 1162047600
          tz.transition 2007, 3, :o3, 1174748400
          tz.transition 2007, 10, :o2, 1193497200
          tz.transition 2008, 3, :o3, 1206802800
          tz.transition 2008, 10, :o2, 1224946800
          tz.transition 2009, 3, :o3, 1238252400
          tz.transition 2009, 10, :o2, 1256396400
          tz.transition 2010, 3, :o3, 1269702000
          tz.transition 2010, 10, :o2, 1288450800
          tz.transition 2011, 3, :o3, 1301151600
          tz.transition 2011, 10, :o2, 1319900400
          tz.transition 2012, 3, :o3, 1332601200
          tz.transition 2012, 10, :o2, 1351350000
          tz.transition 2013, 3, :o3, 1364655600
          tz.transition 2013, 10, :o2, 1382799600
          tz.transition 2014, 3, :o3, 1396105200
          tz.transition 2014, 10, :o2, 1414249200
          tz.transition 2015, 3, :o3, 1427554800
          tz.transition 2015, 10, :o2, 1445698800
          tz.transition 2016, 3, :o3, 1459004400
          tz.transition 2016, 10, :o2, 1477753200
          tz.transition 2017, 3, :o3, 1490454000
          tz.transition 2017, 10, :o2, 1509202800
          tz.transition 2018, 3, :o3, 1521903600
          tz.transition 2018, 10, :o2, 1540652400
          tz.transition 2019, 3, :o3, 1553958000
          tz.transition 2019, 10, :o2, 1572102000
          tz.transition 2020, 3, :o3, 1585407600
          tz.transition 2020, 10, :o2, 1603551600
          tz.transition 2021, 3, :o3, 1616857200
          tz.transition 2021, 10, :o2, 1635606000
          tz.transition 2022, 3, :o3, 1648306800
          tz.transition 2022, 10, :o2, 1667055600
          tz.transition 2023, 3, :o3, 1679756400
          tz.transition 2023, 10, :o2, 1698505200
          tz.transition 2024, 3, :o3, 1711810800
          tz.transition 2024, 10, :o2, 1729954800
          tz.transition 2025, 3, :o3, 1743260400
          tz.transition 2025, 10, :o2, 1761404400
          tz.transition 2026, 3, :o3, 1774710000
          tz.transition 2026, 10, :o2, 1792854000
          tz.transition 2027, 3, :o3, 1806159600
          tz.transition 2027, 10, :o2, 1824908400
          tz.transition 2028, 3, :o3, 1837609200
          tz.transition 2028, 10, :o2, 1856358000
          tz.transition 2029, 3, :o3, 1869058800
          tz.transition 2029, 10, :o2, 1887807600
          tz.transition 2030, 3, :o3, 1901113200
          tz.transition 2030, 10, :o2, 1919257200
          tz.transition 2031, 3, :o3, 1932562800
          tz.transition 2031, 10, :o2, 1950706800
          tz.transition 2032, 3, :o3, 1964012400
          tz.transition 2032, 10, :o2, 1982761200
          tz.transition 2033, 3, :o3, 1995462000
          tz.transition 2033, 10, :o2, 2014210800
          tz.transition 2034, 3, :o3, 2026911600
          tz.transition 2034, 10, :o2, 2045660400
          tz.transition 2035, 3, :o3, 2058361200
          tz.transition 2035, 10, :o2, 2077110000
          tz.transition 2036, 3, :o3, 2090415600
          tz.transition 2036, 10, :o2, 2108559600
          tz.transition 2037, 3, :o3, 2121865200
          tz.transition 2037, 10, :o2, 2140009200
          tz.transition 2038, 3, :o3, 19724081, 8
          tz.transition 2038, 10, :o2, 19725817, 8
          tz.transition 2039, 3, :o3, 19726993, 8
          tz.transition 2039, 10, :o2, 19728729, 8
          tz.transition 2040, 3, :o3, 19729905, 8
          tz.transition 2040, 10, :o2, 19731641, 8
          tz.transition 2041, 3, :o3, 19732873, 8
          tz.transition 2041, 10, :o2, 19734553, 8
          tz.transition 2042, 3, :o3, 19735785, 8
          tz.transition 2042, 10, :o2, 19737465, 8
          tz.transition 2043, 3, :o3, 19738697, 8
          tz.transition 2043, 10, :o2, 19740377, 8
          tz.transition 2044, 3, :o3, 19741609, 8
          tz.transition 2044, 10, :o2, 19743345, 8
          tz.transition 2045, 3, :o3, 19744521, 8
          tz.transition 2045, 10, :o2, 19746257, 8
          tz.transition 2046, 3, :o3, 19747433, 8
          tz.transition 2046, 10, :o2, 19749169, 8
          tz.transition 2047, 3, :o3, 19750401, 8
          tz.transition 2047, 10, :o2, 19752081, 8
          tz.transition 2048, 3, :o3, 19753313, 8
          tz.transition 2048, 10, :o2, 19754993, 8
          tz.transition 2049, 3, :o3, 19756225, 8
          tz.transition 2049, 10, :o2, 19757961, 8
          tz.transition 2050, 3, :o3, 19759137, 8
          tz.transition 2050, 10, :o2, 19760873, 8
        end
      end
    end
  end
end
