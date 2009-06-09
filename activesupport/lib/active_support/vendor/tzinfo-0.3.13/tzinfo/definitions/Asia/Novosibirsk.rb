require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Novosibirsk
        include TimezoneDefinition
        
        timezone 'Asia/Novosibirsk' do |tz|
          tz.offset :o0, 19900, 0, :LMT
          tz.offset :o1, 21600, 0, :NOVT
          tz.offset :o2, 25200, 0, :NOVT
          tz.offset :o3, 25200, 3600, :NOVST
          tz.offset :o4, 21600, 3600, :NOVST
          
          tz.transition 1919, 12, :o1, 2092872833, 864
          tz.transition 1930, 6, :o2, 9704593, 4
          tz.transition 1981, 3, :o3, 354906000
          tz.transition 1981, 9, :o2, 370713600
          tz.transition 1982, 3, :o3, 386442000
          tz.transition 1982, 9, :o2, 402249600
          tz.transition 1983, 3, :o3, 417978000
          tz.transition 1983, 9, :o2, 433785600
          tz.transition 1984, 3, :o3, 449600400
          tz.transition 1984, 9, :o2, 465332400
          tz.transition 1985, 3, :o3, 481057200
          tz.transition 1985, 9, :o2, 496782000
          tz.transition 1986, 3, :o3, 512506800
          tz.transition 1986, 9, :o2, 528231600
          tz.transition 1987, 3, :o3, 543956400
          tz.transition 1987, 9, :o2, 559681200
          tz.transition 1988, 3, :o3, 575406000
          tz.transition 1988, 9, :o2, 591130800
          tz.transition 1989, 3, :o3, 606855600
          tz.transition 1989, 9, :o2, 622580400
          tz.transition 1990, 3, :o3, 638305200
          tz.transition 1990, 9, :o2, 654634800
          tz.transition 1991, 3, :o4, 670359600
          tz.transition 1991, 9, :o1, 686088000
          tz.transition 1992, 1, :o2, 695764800
          tz.transition 1992, 3, :o3, 701798400
          tz.transition 1992, 9, :o2, 717519600
          tz.transition 1993, 3, :o3, 733258800
          tz.transition 1993, 5, :o4, 738086400
          tz.transition 1993, 9, :o1, 748987200
          tz.transition 1994, 3, :o4, 764712000
          tz.transition 1994, 9, :o1, 780436800
          tz.transition 1995, 3, :o4, 796161600
          tz.transition 1995, 9, :o1, 811886400
          tz.transition 1996, 3, :o4, 828216000
          tz.transition 1996, 10, :o1, 846360000
          tz.transition 1997, 3, :o4, 859665600
          tz.transition 1997, 10, :o1, 877809600
          tz.transition 1998, 3, :o4, 891115200
          tz.transition 1998, 10, :o1, 909259200
          tz.transition 1999, 3, :o4, 922564800
          tz.transition 1999, 10, :o1, 941313600
          tz.transition 2000, 3, :o4, 954014400
          tz.transition 2000, 10, :o1, 972763200
          tz.transition 2001, 3, :o4, 985464000
          tz.transition 2001, 10, :o1, 1004212800
          tz.transition 2002, 3, :o4, 1017518400
          tz.transition 2002, 10, :o1, 1035662400
          tz.transition 2003, 3, :o4, 1048968000
          tz.transition 2003, 10, :o1, 1067112000
          tz.transition 2004, 3, :o4, 1080417600
          tz.transition 2004, 10, :o1, 1099166400
          tz.transition 2005, 3, :o4, 1111867200
          tz.transition 2005, 10, :o1, 1130616000
          tz.transition 2006, 3, :o4, 1143316800
          tz.transition 2006, 10, :o1, 1162065600
          tz.transition 2007, 3, :o4, 1174766400
          tz.transition 2007, 10, :o1, 1193515200
          tz.transition 2008, 3, :o4, 1206820800
          tz.transition 2008, 10, :o1, 1224964800
          tz.transition 2009, 3, :o4, 1238270400
          tz.transition 2009, 10, :o1, 1256414400
          tz.transition 2010, 3, :o4, 1269720000
          tz.transition 2010, 10, :o1, 1288468800
          tz.transition 2011, 3, :o4, 1301169600
          tz.transition 2011, 10, :o1, 1319918400
          tz.transition 2012, 3, :o4, 1332619200
          tz.transition 2012, 10, :o1, 1351368000
          tz.transition 2013, 3, :o4, 1364673600
          tz.transition 2013, 10, :o1, 1382817600
          tz.transition 2014, 3, :o4, 1396123200
          tz.transition 2014, 10, :o1, 1414267200
          tz.transition 2015, 3, :o4, 1427572800
          tz.transition 2015, 10, :o1, 1445716800
          tz.transition 2016, 3, :o4, 1459022400
          tz.transition 2016, 10, :o1, 1477771200
          tz.transition 2017, 3, :o4, 1490472000
          tz.transition 2017, 10, :o1, 1509220800
          tz.transition 2018, 3, :o4, 1521921600
          tz.transition 2018, 10, :o1, 1540670400
          tz.transition 2019, 3, :o4, 1553976000
          tz.transition 2019, 10, :o1, 1572120000
          tz.transition 2020, 3, :o4, 1585425600
          tz.transition 2020, 10, :o1, 1603569600
          tz.transition 2021, 3, :o4, 1616875200
          tz.transition 2021, 10, :o1, 1635624000
          tz.transition 2022, 3, :o4, 1648324800
          tz.transition 2022, 10, :o1, 1667073600
          tz.transition 2023, 3, :o4, 1679774400
          tz.transition 2023, 10, :o1, 1698523200
          tz.transition 2024, 3, :o4, 1711828800
          tz.transition 2024, 10, :o1, 1729972800
          tz.transition 2025, 3, :o4, 1743278400
          tz.transition 2025, 10, :o1, 1761422400
          tz.transition 2026, 3, :o4, 1774728000
          tz.transition 2026, 10, :o1, 1792872000
          tz.transition 2027, 3, :o4, 1806177600
          tz.transition 2027, 10, :o1, 1824926400
          tz.transition 2028, 3, :o4, 1837627200
          tz.transition 2028, 10, :o1, 1856376000
          tz.transition 2029, 3, :o4, 1869076800
          tz.transition 2029, 10, :o1, 1887825600
          tz.transition 2030, 3, :o4, 1901131200
          tz.transition 2030, 10, :o1, 1919275200
          tz.transition 2031, 3, :o4, 1932580800
          tz.transition 2031, 10, :o1, 1950724800
          tz.transition 2032, 3, :o4, 1964030400
          tz.transition 2032, 10, :o1, 1982779200
          tz.transition 2033, 3, :o4, 1995480000
          tz.transition 2033, 10, :o1, 2014228800
          tz.transition 2034, 3, :o4, 2026929600
          tz.transition 2034, 10, :o1, 2045678400
          tz.transition 2035, 3, :o4, 2058379200
          tz.transition 2035, 10, :o1, 2077128000
          tz.transition 2036, 3, :o4, 2090433600
          tz.transition 2036, 10, :o1, 2108577600
          tz.transition 2037, 3, :o4, 2121883200
          tz.transition 2037, 10, :o1, 2140027200
          tz.transition 2038, 3, :o4, 7396531, 3
          tz.transition 2038, 10, :o1, 7397182, 3
          tz.transition 2039, 3, :o4, 7397623, 3
          tz.transition 2039, 10, :o1, 7398274, 3
          tz.transition 2040, 3, :o4, 7398715, 3
          tz.transition 2040, 10, :o1, 7399366, 3
          tz.transition 2041, 3, :o4, 7399828, 3
          tz.transition 2041, 10, :o1, 7400458, 3
          tz.transition 2042, 3, :o4, 7400920, 3
          tz.transition 2042, 10, :o1, 7401550, 3
          tz.transition 2043, 3, :o4, 7402012, 3
          tz.transition 2043, 10, :o1, 7402642, 3
          tz.transition 2044, 3, :o4, 7403104, 3
          tz.transition 2044, 10, :o1, 7403755, 3
          tz.transition 2045, 3, :o4, 7404196, 3
          tz.transition 2045, 10, :o1, 7404847, 3
          tz.transition 2046, 3, :o4, 7405288, 3
          tz.transition 2046, 10, :o1, 7405939, 3
          tz.transition 2047, 3, :o4, 7406401, 3
          tz.transition 2047, 10, :o1, 7407031, 3
          tz.transition 2048, 3, :o4, 7407493, 3
          tz.transition 2048, 10, :o1, 7408123, 3
          tz.transition 2049, 3, :o4, 7408585, 3
          tz.transition 2049, 10, :o1, 7409236, 3
          tz.transition 2050, 3, :o4, 7409677, 3
          tz.transition 2050, 10, :o1, 7410328, 3
        end
      end
    end
  end
end
