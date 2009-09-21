require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Vladivostok
        include TimezoneDefinition
        
        timezone 'Asia/Vladivostok' do |tz|
          tz.offset :o0, 31664, 0, :LMT
          tz.offset :o1, 32400, 0, :VLAT
          tz.offset :o2, 36000, 0, :VLAT
          tz.offset :o3, 36000, 3600, :VLAST
          tz.offset :o4, 32400, 3600, :VLASST
          tz.offset :o5, 32400, 0, :VLAST
          
          tz.transition 1922, 11, :o1, 13086214921, 5400
          tz.transition 1930, 6, :o2, 19409185, 8
          tz.transition 1981, 3, :o3, 354895200
          tz.transition 1981, 9, :o2, 370702800
          tz.transition 1982, 3, :o3, 386431200
          tz.transition 1982, 9, :o2, 402238800
          tz.transition 1983, 3, :o3, 417967200
          tz.transition 1983, 9, :o2, 433774800
          tz.transition 1984, 3, :o3, 449589600
          tz.transition 1984, 9, :o2, 465321600
          tz.transition 1985, 3, :o3, 481046400
          tz.transition 1985, 9, :o2, 496771200
          tz.transition 1986, 3, :o3, 512496000
          tz.transition 1986, 9, :o2, 528220800
          tz.transition 1987, 3, :o3, 543945600
          tz.transition 1987, 9, :o2, 559670400
          tz.transition 1988, 3, :o3, 575395200
          tz.transition 1988, 9, :o2, 591120000
          tz.transition 1989, 3, :o3, 606844800
          tz.transition 1989, 9, :o2, 622569600
          tz.transition 1990, 3, :o3, 638294400
          tz.transition 1990, 9, :o2, 654624000
          tz.transition 1991, 3, :o4, 670348800
          tz.transition 1991, 9, :o5, 686077200
          tz.transition 1992, 1, :o2, 695754000
          tz.transition 1992, 3, :o3, 701787600
          tz.transition 1992, 9, :o2, 717508800
          tz.transition 1993, 3, :o3, 733248000
          tz.transition 1993, 9, :o2, 748972800
          tz.transition 1994, 3, :o3, 764697600
          tz.transition 1994, 9, :o2, 780422400
          tz.transition 1995, 3, :o3, 796147200
          tz.transition 1995, 9, :o2, 811872000
          tz.transition 1996, 3, :o3, 828201600
          tz.transition 1996, 10, :o2, 846345600
          tz.transition 1997, 3, :o3, 859651200
          tz.transition 1997, 10, :o2, 877795200
          tz.transition 1998, 3, :o3, 891100800
          tz.transition 1998, 10, :o2, 909244800
          tz.transition 1999, 3, :o3, 922550400
          tz.transition 1999, 10, :o2, 941299200
          tz.transition 2000, 3, :o3, 954000000
          tz.transition 2000, 10, :o2, 972748800
          tz.transition 2001, 3, :o3, 985449600
          tz.transition 2001, 10, :o2, 1004198400
          tz.transition 2002, 3, :o3, 1017504000
          tz.transition 2002, 10, :o2, 1035648000
          tz.transition 2003, 3, :o3, 1048953600
          tz.transition 2003, 10, :o2, 1067097600
          tz.transition 2004, 3, :o3, 1080403200
          tz.transition 2004, 10, :o2, 1099152000
          tz.transition 2005, 3, :o3, 1111852800
          tz.transition 2005, 10, :o2, 1130601600
          tz.transition 2006, 3, :o3, 1143302400
          tz.transition 2006, 10, :o2, 1162051200
          tz.transition 2007, 3, :o3, 1174752000
          tz.transition 2007, 10, :o2, 1193500800
          tz.transition 2008, 3, :o3, 1206806400
          tz.transition 2008, 10, :o2, 1224950400
          tz.transition 2009, 3, :o3, 1238256000
          tz.transition 2009, 10, :o2, 1256400000
          tz.transition 2010, 3, :o3, 1269705600
          tz.transition 2010, 10, :o2, 1288454400
          tz.transition 2011, 3, :o3, 1301155200
          tz.transition 2011, 10, :o2, 1319904000
          tz.transition 2012, 3, :o3, 1332604800
          tz.transition 2012, 10, :o2, 1351353600
          tz.transition 2013, 3, :o3, 1364659200
          tz.transition 2013, 10, :o2, 1382803200
          tz.transition 2014, 3, :o3, 1396108800
          tz.transition 2014, 10, :o2, 1414252800
          tz.transition 2015, 3, :o3, 1427558400
          tz.transition 2015, 10, :o2, 1445702400
          tz.transition 2016, 3, :o3, 1459008000
          tz.transition 2016, 10, :o2, 1477756800
          tz.transition 2017, 3, :o3, 1490457600
          tz.transition 2017, 10, :o2, 1509206400
          tz.transition 2018, 3, :o3, 1521907200
          tz.transition 2018, 10, :o2, 1540656000
          tz.transition 2019, 3, :o3, 1553961600
          tz.transition 2019, 10, :o2, 1572105600
          tz.transition 2020, 3, :o3, 1585411200
          tz.transition 2020, 10, :o2, 1603555200
          tz.transition 2021, 3, :o3, 1616860800
          tz.transition 2021, 10, :o2, 1635609600
          tz.transition 2022, 3, :o3, 1648310400
          tz.transition 2022, 10, :o2, 1667059200
          tz.transition 2023, 3, :o3, 1679760000
          tz.transition 2023, 10, :o2, 1698508800
          tz.transition 2024, 3, :o3, 1711814400
          tz.transition 2024, 10, :o2, 1729958400
          tz.transition 2025, 3, :o3, 1743264000
          tz.transition 2025, 10, :o2, 1761408000
          tz.transition 2026, 3, :o3, 1774713600
          tz.transition 2026, 10, :o2, 1792857600
          tz.transition 2027, 3, :o3, 1806163200
          tz.transition 2027, 10, :o2, 1824912000
          tz.transition 2028, 3, :o3, 1837612800
          tz.transition 2028, 10, :o2, 1856361600
          tz.transition 2029, 3, :o3, 1869062400
          tz.transition 2029, 10, :o2, 1887811200
          tz.transition 2030, 3, :o3, 1901116800
          tz.transition 2030, 10, :o2, 1919260800
          tz.transition 2031, 3, :o3, 1932566400
          tz.transition 2031, 10, :o2, 1950710400
          tz.transition 2032, 3, :o3, 1964016000
          tz.transition 2032, 10, :o2, 1982764800
          tz.transition 2033, 3, :o3, 1995465600
          tz.transition 2033, 10, :o2, 2014214400
          tz.transition 2034, 3, :o3, 2026915200
          tz.transition 2034, 10, :o2, 2045664000
          tz.transition 2035, 3, :o3, 2058364800
          tz.transition 2035, 10, :o2, 2077113600
          tz.transition 2036, 3, :o3, 2090419200
          tz.transition 2036, 10, :o2, 2108563200
          tz.transition 2037, 3, :o3, 2121868800
          tz.transition 2037, 10, :o2, 2140012800
          tz.transition 2038, 3, :o3, 14793061, 6
          tz.transition 2038, 10, :o2, 14794363, 6
          tz.transition 2039, 3, :o3, 14795245, 6
          tz.transition 2039, 10, :o2, 14796547, 6
          tz.transition 2040, 3, :o3, 14797429, 6
          tz.transition 2040, 10, :o2, 14798731, 6
          tz.transition 2041, 3, :o3, 14799655, 6
          tz.transition 2041, 10, :o2, 14800915, 6
          tz.transition 2042, 3, :o3, 14801839, 6
          tz.transition 2042, 10, :o2, 14803099, 6
          tz.transition 2043, 3, :o3, 14804023, 6
          tz.transition 2043, 10, :o2, 14805283, 6
          tz.transition 2044, 3, :o3, 14806207, 6
          tz.transition 2044, 10, :o2, 14807509, 6
          tz.transition 2045, 3, :o3, 14808391, 6
          tz.transition 2045, 10, :o2, 14809693, 6
          tz.transition 2046, 3, :o3, 14810575, 6
          tz.transition 2046, 10, :o2, 14811877, 6
          tz.transition 2047, 3, :o3, 14812801, 6
          tz.transition 2047, 10, :o2, 14814061, 6
          tz.transition 2048, 3, :o3, 14814985, 6
          tz.transition 2048, 10, :o2, 14816245, 6
          tz.transition 2049, 3, :o3, 14817169, 6
          tz.transition 2049, 10, :o2, 14818471, 6
          tz.transition 2050, 3, :o3, 14819353, 6
          tz.transition 2050, 10, :o2, 14820655, 6
        end
      end
    end
  end
end
