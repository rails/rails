require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Europe
      module Vilnius
        include TimezoneDefinition
        
        timezone 'Europe/Vilnius' do |tz|
          tz.offset :o0, 6076, 0, :LMT
          tz.offset :o1, 5040, 0, :WMT
          tz.offset :o2, 5736, 0, :KMT
          tz.offset :o3, 3600, 0, :CET
          tz.offset :o4, 7200, 0, :EET
          tz.offset :o5, 10800, 0, :MSK
          tz.offset :o6, 3600, 3600, :CEST
          tz.offset :o7, 10800, 3600, :MSD
          tz.offset :o8, 7200, 3600, :EEST
          
          tz.transition 1879, 12, :o1, 52006653281, 21600
          tz.transition 1916, 12, :o2, 290547533, 120
          tz.transition 1919, 10, :o3, 8720069161, 3600
          tz.transition 1920, 7, :o4, 58140419, 24
          tz.transition 1920, 10, :o3, 29071277, 12
          tz.transition 1940, 8, :o5, 58316267, 24
          tz.transition 1941, 6, :o6, 19441355, 8
          tz.transition 1942, 11, :o3, 58335973, 24
          tz.transition 1943, 3, :o6, 58339501, 24
          tz.transition 1943, 10, :o3, 58344037, 24
          tz.transition 1944, 4, :o6, 58348405, 24
          tz.transition 1944, 7, :o5, 29175641, 12
          tz.transition 1981, 3, :o7, 354920400
          tz.transition 1981, 9, :o5, 370728000
          tz.transition 1982, 3, :o7, 386456400
          tz.transition 1982, 9, :o5, 402264000
          tz.transition 1983, 3, :o7, 417992400
          tz.transition 1983, 9, :o5, 433800000
          tz.transition 1984, 3, :o7, 449614800
          tz.transition 1984, 9, :o5, 465346800
          tz.transition 1985, 3, :o7, 481071600
          tz.transition 1985, 9, :o5, 496796400
          tz.transition 1986, 3, :o7, 512521200
          tz.transition 1986, 9, :o5, 528246000
          tz.transition 1987, 3, :o7, 543970800
          tz.transition 1987, 9, :o5, 559695600
          tz.transition 1988, 3, :o7, 575420400
          tz.transition 1988, 9, :o5, 591145200
          tz.transition 1989, 3, :o7, 606870000
          tz.transition 1989, 9, :o5, 622594800
          tz.transition 1990, 3, :o7, 638319600
          tz.transition 1990, 9, :o5, 654649200
          tz.transition 1991, 3, :o8, 670374000
          tz.transition 1991, 9, :o4, 686102400
          tz.transition 1992, 3, :o8, 701827200
          tz.transition 1992, 9, :o4, 717552000
          tz.transition 1993, 3, :o8, 733276800
          tz.transition 1993, 9, :o4, 749001600
          tz.transition 1994, 3, :o8, 764726400
          tz.transition 1994, 9, :o4, 780451200
          tz.transition 1995, 3, :o8, 796176000
          tz.transition 1995, 9, :o4, 811900800
          tz.transition 1996, 3, :o8, 828230400
          tz.transition 1996, 10, :o4, 846374400
          tz.transition 1997, 3, :o8, 859680000
          tz.transition 1997, 10, :o4, 877824000
          tz.transition 1998, 3, :o6, 891133200
          tz.transition 1998, 10, :o3, 909277200
          tz.transition 1999, 3, :o6, 922582800
          tz.transition 1999, 10, :o4, 941331600
          tz.transition 2003, 3, :o8, 1048986000
          tz.transition 2003, 10, :o4, 1067130000
          tz.transition 2004, 3, :o8, 1080435600
          tz.transition 2004, 10, :o4, 1099184400
          tz.transition 2005, 3, :o8, 1111885200
          tz.transition 2005, 10, :o4, 1130634000
          tz.transition 2006, 3, :o8, 1143334800
          tz.transition 2006, 10, :o4, 1162083600
          tz.transition 2007, 3, :o8, 1174784400
          tz.transition 2007, 10, :o4, 1193533200
          tz.transition 2008, 3, :o8, 1206838800
          tz.transition 2008, 10, :o4, 1224982800
          tz.transition 2009, 3, :o8, 1238288400
          tz.transition 2009, 10, :o4, 1256432400
          tz.transition 2010, 3, :o8, 1269738000
          tz.transition 2010, 10, :o4, 1288486800
          tz.transition 2011, 3, :o8, 1301187600
          tz.transition 2011, 10, :o4, 1319936400
          tz.transition 2012, 3, :o8, 1332637200
          tz.transition 2012, 10, :o4, 1351386000
          tz.transition 2013, 3, :o8, 1364691600
          tz.transition 2013, 10, :o4, 1382835600
          tz.transition 2014, 3, :o8, 1396141200
          tz.transition 2014, 10, :o4, 1414285200
          tz.transition 2015, 3, :o8, 1427590800
          tz.transition 2015, 10, :o4, 1445734800
          tz.transition 2016, 3, :o8, 1459040400
          tz.transition 2016, 10, :o4, 1477789200
          tz.transition 2017, 3, :o8, 1490490000
          tz.transition 2017, 10, :o4, 1509238800
          tz.transition 2018, 3, :o8, 1521939600
          tz.transition 2018, 10, :o4, 1540688400
          tz.transition 2019, 3, :o8, 1553994000
          tz.transition 2019, 10, :o4, 1572138000
          tz.transition 2020, 3, :o8, 1585443600
          tz.transition 2020, 10, :o4, 1603587600
          tz.transition 2021, 3, :o8, 1616893200
          tz.transition 2021, 10, :o4, 1635642000
          tz.transition 2022, 3, :o8, 1648342800
          tz.transition 2022, 10, :o4, 1667091600
          tz.transition 2023, 3, :o8, 1679792400
          tz.transition 2023, 10, :o4, 1698541200
          tz.transition 2024, 3, :o8, 1711846800
          tz.transition 2024, 10, :o4, 1729990800
          tz.transition 2025, 3, :o8, 1743296400
          tz.transition 2025, 10, :o4, 1761440400
          tz.transition 2026, 3, :o8, 1774746000
          tz.transition 2026, 10, :o4, 1792890000
          tz.transition 2027, 3, :o8, 1806195600
          tz.transition 2027, 10, :o4, 1824944400
          tz.transition 2028, 3, :o8, 1837645200
          tz.transition 2028, 10, :o4, 1856394000
          tz.transition 2029, 3, :o8, 1869094800
          tz.transition 2029, 10, :o4, 1887843600
          tz.transition 2030, 3, :o8, 1901149200
          tz.transition 2030, 10, :o4, 1919293200
          tz.transition 2031, 3, :o8, 1932598800
          tz.transition 2031, 10, :o4, 1950742800
          tz.transition 2032, 3, :o8, 1964048400
          tz.transition 2032, 10, :o4, 1982797200
          tz.transition 2033, 3, :o8, 1995498000
          tz.transition 2033, 10, :o4, 2014246800
          tz.transition 2034, 3, :o8, 2026947600
          tz.transition 2034, 10, :o4, 2045696400
          tz.transition 2035, 3, :o8, 2058397200
          tz.transition 2035, 10, :o4, 2077146000
          tz.transition 2036, 3, :o8, 2090451600
          tz.transition 2036, 10, :o4, 2108595600
          tz.transition 2037, 3, :o8, 2121901200
          tz.transition 2037, 10, :o4, 2140045200
          tz.transition 2038, 3, :o8, 59172253, 24
          tz.transition 2038, 10, :o4, 59177461, 24
          tz.transition 2039, 3, :o8, 59180989, 24
          tz.transition 2039, 10, :o4, 59186197, 24
          tz.transition 2040, 3, :o8, 59189725, 24
          tz.transition 2040, 10, :o4, 59194933, 24
          tz.transition 2041, 3, :o8, 59198629, 24
          tz.transition 2041, 10, :o4, 59203669, 24
          tz.transition 2042, 3, :o8, 59207365, 24
          tz.transition 2042, 10, :o4, 59212405, 24
          tz.transition 2043, 3, :o8, 59216101, 24
          tz.transition 2043, 10, :o4, 59221141, 24
          tz.transition 2044, 3, :o8, 59224837, 24
          tz.transition 2044, 10, :o4, 59230045, 24
          tz.transition 2045, 3, :o8, 59233573, 24
          tz.transition 2045, 10, :o4, 59238781, 24
          tz.transition 2046, 3, :o8, 59242309, 24
          tz.transition 2046, 10, :o4, 59247517, 24
          tz.transition 2047, 3, :o8, 59251213, 24
          tz.transition 2047, 10, :o4, 59256253, 24
          tz.transition 2048, 3, :o8, 59259949, 24
          tz.transition 2048, 10, :o4, 59264989, 24
          tz.transition 2049, 3, :o8, 59268685, 24
          tz.transition 2049, 10, :o4, 59273893, 24
          tz.transition 2050, 3, :o8, 59277421, 24
          tz.transition 2050, 10, :o4, 59282629, 24
        end
      end
    end
  end
end
