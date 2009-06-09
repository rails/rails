require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Europe
      module Paris
        include TimezoneDefinition
        
        timezone 'Europe/Paris' do |tz|
          tz.offset :o0, 561, 0, :LMT
          tz.offset :o1, 561, 0, :PMT
          tz.offset :o2, 0, 0, :WET
          tz.offset :o3, 0, 3600, :WEST
          tz.offset :o4, 3600, 3600, :CEST
          tz.offset :o5, 3600, 0, :CET
          tz.offset :o6, 0, 7200, :WEMT
          
          tz.transition 1891, 3, :o1, 69460027033, 28800
          tz.transition 1911, 3, :o2, 69670267033, 28800
          tz.transition 1916, 6, :o3, 58104707, 24
          tz.transition 1916, 10, :o2, 58107323, 24
          tz.transition 1917, 3, :o3, 58111499, 24
          tz.transition 1917, 10, :o2, 58116227, 24
          tz.transition 1918, 3, :o3, 58119899, 24
          tz.transition 1918, 10, :o2, 58124963, 24
          tz.transition 1919, 3, :o3, 58128467, 24
          tz.transition 1919, 10, :o2, 58133699, 24
          tz.transition 1920, 2, :o3, 58136867, 24
          tz.transition 1920, 10, :o2, 58142915, 24
          tz.transition 1921, 3, :o3, 58146323, 24
          tz.transition 1921, 10, :o2, 58151723, 24
          tz.transition 1922, 3, :o3, 58155347, 24
          tz.transition 1922, 10, :o2, 58160051, 24
          tz.transition 1923, 5, :o3, 58165595, 24
          tz.transition 1923, 10, :o2, 58168787, 24
          tz.transition 1924, 3, :o3, 58172987, 24
          tz.transition 1924, 10, :o2, 58177523, 24
          tz.transition 1925, 4, :o3, 58181891, 24
          tz.transition 1925, 10, :o2, 58186259, 24
          tz.transition 1926, 4, :o3, 58190963, 24
          tz.transition 1926, 10, :o2, 58194995, 24
          tz.transition 1927, 4, :o3, 58199531, 24
          tz.transition 1927, 10, :o2, 58203731, 24
          tz.transition 1928, 4, :o3, 58208435, 24
          tz.transition 1928, 10, :o2, 58212635, 24
          tz.transition 1929, 4, :o3, 58217339, 24
          tz.transition 1929, 10, :o2, 58221371, 24
          tz.transition 1930, 4, :o3, 58225907, 24
          tz.transition 1930, 10, :o2, 58230107, 24
          tz.transition 1931, 4, :o3, 58234811, 24
          tz.transition 1931, 10, :o2, 58238843, 24
          tz.transition 1932, 4, :o3, 58243211, 24
          tz.transition 1932, 10, :o2, 58247579, 24
          tz.transition 1933, 3, :o3, 58251779, 24
          tz.transition 1933, 10, :o2, 58256483, 24
          tz.transition 1934, 4, :o3, 58260851, 24
          tz.transition 1934, 10, :o2, 58265219, 24
          tz.transition 1935, 3, :o3, 58269419, 24
          tz.transition 1935, 10, :o2, 58273955, 24
          tz.transition 1936, 4, :o3, 58278659, 24
          tz.transition 1936, 10, :o2, 58282691, 24
          tz.transition 1937, 4, :o3, 58287059, 24
          tz.transition 1937, 10, :o2, 58291427, 24
          tz.transition 1938, 3, :o3, 58295627, 24
          tz.transition 1938, 10, :o2, 58300163, 24
          tz.transition 1939, 4, :o3, 58304867, 24
          tz.transition 1939, 11, :o2, 58310075, 24
          tz.transition 1940, 2, :o3, 29156215, 12
          tz.transition 1940, 6, :o4, 29157545, 12
          tz.transition 1942, 11, :o5, 58335973, 24
          tz.transition 1943, 3, :o4, 58339501, 24
          tz.transition 1943, 10, :o5, 58344037, 24
          tz.transition 1944, 4, :o4, 58348405, 24
          tz.transition 1944, 8, :o6, 29175929, 12
          tz.transition 1944, 10, :o3, 58352915, 24
          tz.transition 1945, 4, :o6, 58357141, 24
          tz.transition 1945, 9, :o5, 58361149, 24
          tz.transition 1976, 3, :o4, 196819200
          tz.transition 1976, 9, :o5, 212540400
          tz.transition 1977, 4, :o4, 228877200
          tz.transition 1977, 9, :o5, 243997200
          tz.transition 1978, 4, :o4, 260326800
          tz.transition 1978, 10, :o5, 276051600
          tz.transition 1979, 4, :o4, 291776400
          tz.transition 1979, 9, :o5, 307501200
          tz.transition 1980, 4, :o4, 323830800
          tz.transition 1980, 9, :o5, 338950800
          tz.transition 1981, 3, :o4, 354675600
          tz.transition 1981, 9, :o5, 370400400
          tz.transition 1982, 3, :o4, 386125200
          tz.transition 1982, 9, :o5, 401850000
          tz.transition 1983, 3, :o4, 417574800
          tz.transition 1983, 9, :o5, 433299600
          tz.transition 1984, 3, :o4, 449024400
          tz.transition 1984, 9, :o5, 465354000
          tz.transition 1985, 3, :o4, 481078800
          tz.transition 1985, 9, :o5, 496803600
          tz.transition 1986, 3, :o4, 512528400
          tz.transition 1986, 9, :o5, 528253200
          tz.transition 1987, 3, :o4, 543978000
          tz.transition 1987, 9, :o5, 559702800
          tz.transition 1988, 3, :o4, 575427600
          tz.transition 1988, 9, :o5, 591152400
          tz.transition 1989, 3, :o4, 606877200
          tz.transition 1989, 9, :o5, 622602000
          tz.transition 1990, 3, :o4, 638326800
          tz.transition 1990, 9, :o5, 654656400
          tz.transition 1991, 3, :o4, 670381200
          tz.transition 1991, 9, :o5, 686106000
          tz.transition 1992, 3, :o4, 701830800
          tz.transition 1992, 9, :o5, 717555600
          tz.transition 1993, 3, :o4, 733280400
          tz.transition 1993, 9, :o5, 749005200
          tz.transition 1994, 3, :o4, 764730000
          tz.transition 1994, 9, :o5, 780454800
          tz.transition 1995, 3, :o4, 796179600
          tz.transition 1995, 9, :o5, 811904400
          tz.transition 1996, 3, :o4, 828234000
          tz.transition 1996, 10, :o5, 846378000
          tz.transition 1997, 3, :o4, 859683600
          tz.transition 1997, 10, :o5, 877827600
          tz.transition 1998, 3, :o4, 891133200
          tz.transition 1998, 10, :o5, 909277200
          tz.transition 1999, 3, :o4, 922582800
          tz.transition 1999, 10, :o5, 941331600
          tz.transition 2000, 3, :o4, 954032400
          tz.transition 2000, 10, :o5, 972781200
          tz.transition 2001, 3, :o4, 985482000
          tz.transition 2001, 10, :o5, 1004230800
          tz.transition 2002, 3, :o4, 1017536400
          tz.transition 2002, 10, :o5, 1035680400
          tz.transition 2003, 3, :o4, 1048986000
          tz.transition 2003, 10, :o5, 1067130000
          tz.transition 2004, 3, :o4, 1080435600
          tz.transition 2004, 10, :o5, 1099184400
          tz.transition 2005, 3, :o4, 1111885200
          tz.transition 2005, 10, :o5, 1130634000
          tz.transition 2006, 3, :o4, 1143334800
          tz.transition 2006, 10, :o5, 1162083600
          tz.transition 2007, 3, :o4, 1174784400
          tz.transition 2007, 10, :o5, 1193533200
          tz.transition 2008, 3, :o4, 1206838800
          tz.transition 2008, 10, :o5, 1224982800
          tz.transition 2009, 3, :o4, 1238288400
          tz.transition 2009, 10, :o5, 1256432400
          tz.transition 2010, 3, :o4, 1269738000
          tz.transition 2010, 10, :o5, 1288486800
          tz.transition 2011, 3, :o4, 1301187600
          tz.transition 2011, 10, :o5, 1319936400
          tz.transition 2012, 3, :o4, 1332637200
          tz.transition 2012, 10, :o5, 1351386000
          tz.transition 2013, 3, :o4, 1364691600
          tz.transition 2013, 10, :o5, 1382835600
          tz.transition 2014, 3, :o4, 1396141200
          tz.transition 2014, 10, :o5, 1414285200
          tz.transition 2015, 3, :o4, 1427590800
          tz.transition 2015, 10, :o5, 1445734800
          tz.transition 2016, 3, :o4, 1459040400
          tz.transition 2016, 10, :o5, 1477789200
          tz.transition 2017, 3, :o4, 1490490000
          tz.transition 2017, 10, :o5, 1509238800
          tz.transition 2018, 3, :o4, 1521939600
          tz.transition 2018, 10, :o5, 1540688400
          tz.transition 2019, 3, :o4, 1553994000
          tz.transition 2019, 10, :o5, 1572138000
          tz.transition 2020, 3, :o4, 1585443600
          tz.transition 2020, 10, :o5, 1603587600
          tz.transition 2021, 3, :o4, 1616893200
          tz.transition 2021, 10, :o5, 1635642000
          tz.transition 2022, 3, :o4, 1648342800
          tz.transition 2022, 10, :o5, 1667091600
          tz.transition 2023, 3, :o4, 1679792400
          tz.transition 2023, 10, :o5, 1698541200
          tz.transition 2024, 3, :o4, 1711846800
          tz.transition 2024, 10, :o5, 1729990800
          tz.transition 2025, 3, :o4, 1743296400
          tz.transition 2025, 10, :o5, 1761440400
          tz.transition 2026, 3, :o4, 1774746000
          tz.transition 2026, 10, :o5, 1792890000
          tz.transition 2027, 3, :o4, 1806195600
          tz.transition 2027, 10, :o5, 1824944400
          tz.transition 2028, 3, :o4, 1837645200
          tz.transition 2028, 10, :o5, 1856394000
          tz.transition 2029, 3, :o4, 1869094800
          tz.transition 2029, 10, :o5, 1887843600
          tz.transition 2030, 3, :o4, 1901149200
          tz.transition 2030, 10, :o5, 1919293200
          tz.transition 2031, 3, :o4, 1932598800
          tz.transition 2031, 10, :o5, 1950742800
          tz.transition 2032, 3, :o4, 1964048400
          tz.transition 2032, 10, :o5, 1982797200
          tz.transition 2033, 3, :o4, 1995498000
          tz.transition 2033, 10, :o5, 2014246800
          tz.transition 2034, 3, :o4, 2026947600
          tz.transition 2034, 10, :o5, 2045696400
          tz.transition 2035, 3, :o4, 2058397200
          tz.transition 2035, 10, :o5, 2077146000
          tz.transition 2036, 3, :o4, 2090451600
          tz.transition 2036, 10, :o5, 2108595600
          tz.transition 2037, 3, :o4, 2121901200
          tz.transition 2037, 10, :o5, 2140045200
          tz.transition 2038, 3, :o4, 59172253, 24
          tz.transition 2038, 10, :o5, 59177461, 24
          tz.transition 2039, 3, :o4, 59180989, 24
          tz.transition 2039, 10, :o5, 59186197, 24
          tz.transition 2040, 3, :o4, 59189725, 24
          tz.transition 2040, 10, :o5, 59194933, 24
          tz.transition 2041, 3, :o4, 59198629, 24
          tz.transition 2041, 10, :o5, 59203669, 24
          tz.transition 2042, 3, :o4, 59207365, 24
          tz.transition 2042, 10, :o5, 59212405, 24
          tz.transition 2043, 3, :o4, 59216101, 24
          tz.transition 2043, 10, :o5, 59221141, 24
          tz.transition 2044, 3, :o4, 59224837, 24
          tz.transition 2044, 10, :o5, 59230045, 24
          tz.transition 2045, 3, :o4, 59233573, 24
          tz.transition 2045, 10, :o5, 59238781, 24
          tz.transition 2046, 3, :o4, 59242309, 24
          tz.transition 2046, 10, :o5, 59247517, 24
          tz.transition 2047, 3, :o4, 59251213, 24
          tz.transition 2047, 10, :o5, 59256253, 24
          tz.transition 2048, 3, :o4, 59259949, 24
          tz.transition 2048, 10, :o5, 59264989, 24
          tz.transition 2049, 3, :o4, 59268685, 24
          tz.transition 2049, 10, :o5, 59273893, 24
          tz.transition 2050, 3, :o4, 59277421, 24
          tz.transition 2050, 10, :o5, 59282629, 24
        end
      end
    end
  end
end
