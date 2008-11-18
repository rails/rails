require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Europe
      module Brussels
        include TimezoneDefinition
        
        timezone 'Europe/Brussels' do |tz|
          tz.offset :o0, 1050, 0, :LMT
          tz.offset :o1, 1050, 0, :BMT
          tz.offset :o2, 0, 0, :WET
          tz.offset :o3, 3600, 0, :CET
          tz.offset :o4, 3600, 3600, :CEST
          tz.offset :o5, 0, 3600, :WEST
          
          tz.transition 1879, 12, :o1, 1386844121, 576
          tz.transition 1892, 5, :o2, 1389438713, 576
          tz.transition 1914, 11, :o3, 4840889, 2
          tz.transition 1916, 4, :o4, 58103627, 24
          tz.transition 1916, 9, :o3, 58107299, 24
          tz.transition 1917, 4, :o4, 58112029, 24
          tz.transition 1917, 9, :o3, 58115725, 24
          tz.transition 1918, 4, :o4, 58120765, 24
          tz.transition 1918, 9, :o3, 58124461, 24
          tz.transition 1918, 11, :o2, 58125815, 24
          tz.transition 1919, 3, :o5, 58128467, 24
          tz.transition 1919, 10, :o2, 58133675, 24
          tz.transition 1920, 2, :o5, 58136867, 24
          tz.transition 1920, 10, :o2, 58142915, 24
          tz.transition 1921, 3, :o5, 58146323, 24
          tz.transition 1921, 10, :o2, 58151723, 24
          tz.transition 1922, 3, :o5, 58155347, 24
          tz.transition 1922, 10, :o2, 58160051, 24
          tz.transition 1923, 4, :o5, 58164755, 24
          tz.transition 1923, 10, :o2, 58168787, 24
          tz.transition 1924, 3, :o5, 58172987, 24
          tz.transition 1924, 10, :o2, 58177523, 24
          tz.transition 1925, 4, :o5, 58181891, 24
          tz.transition 1925, 10, :o2, 58186259, 24
          tz.transition 1926, 4, :o5, 58190963, 24
          tz.transition 1926, 10, :o2, 58194995, 24
          tz.transition 1927, 4, :o5, 58199531, 24
          tz.transition 1927, 10, :o2, 58203731, 24
          tz.transition 1928, 4, :o5, 58208435, 24
          tz.transition 1928, 10, :o2, 29106319, 12
          tz.transition 1929, 4, :o5, 29108671, 12
          tz.transition 1929, 10, :o2, 29110687, 12
          tz.transition 1930, 4, :o5, 29112955, 12
          tz.transition 1930, 10, :o2, 29115055, 12
          tz.transition 1931, 4, :o5, 29117407, 12
          tz.transition 1931, 10, :o2, 29119423, 12
          tz.transition 1932, 4, :o5, 29121607, 12
          tz.transition 1932, 10, :o2, 29123791, 12
          tz.transition 1933, 3, :o5, 29125891, 12
          tz.transition 1933, 10, :o2, 29128243, 12
          tz.transition 1934, 4, :o5, 29130427, 12
          tz.transition 1934, 10, :o2, 29132611, 12
          tz.transition 1935, 3, :o5, 29134711, 12
          tz.transition 1935, 10, :o2, 29136979, 12
          tz.transition 1936, 4, :o5, 29139331, 12
          tz.transition 1936, 10, :o2, 29141347, 12
          tz.transition 1937, 4, :o5, 29143531, 12
          tz.transition 1937, 10, :o2, 29145715, 12
          tz.transition 1938, 3, :o5, 29147815, 12
          tz.transition 1938, 10, :o2, 29150083, 12
          tz.transition 1939, 4, :o5, 29152435, 12
          tz.transition 1939, 11, :o2, 29155039, 12
          tz.transition 1940, 2, :o5, 29156215, 12
          tz.transition 1940, 5, :o4, 29157235, 12
          tz.transition 1942, 11, :o3, 58335973, 24
          tz.transition 1943, 3, :o4, 58339501, 24
          tz.transition 1943, 10, :o3, 58344037, 24
          tz.transition 1944, 4, :o4, 58348405, 24
          tz.transition 1944, 9, :o3, 58352413, 24
          tz.transition 1945, 4, :o4, 58357141, 24
          tz.transition 1945, 9, :o3, 58361149, 24
          tz.transition 1946, 5, :o4, 58367029, 24
          tz.transition 1946, 10, :o3, 58370413, 24
          tz.transition 1977, 4, :o4, 228877200
          tz.transition 1977, 9, :o3, 243997200
          tz.transition 1978, 4, :o4, 260326800
          tz.transition 1978, 10, :o3, 276051600
          tz.transition 1979, 4, :o4, 291776400
          tz.transition 1979, 9, :o3, 307501200
          tz.transition 1980, 4, :o4, 323830800
          tz.transition 1980, 9, :o3, 338950800
          tz.transition 1981, 3, :o4, 354675600
          tz.transition 1981, 9, :o3, 370400400
          tz.transition 1982, 3, :o4, 386125200
          tz.transition 1982, 9, :o3, 401850000
          tz.transition 1983, 3, :o4, 417574800
          tz.transition 1983, 9, :o3, 433299600
          tz.transition 1984, 3, :o4, 449024400
          tz.transition 1984, 9, :o3, 465354000
          tz.transition 1985, 3, :o4, 481078800
          tz.transition 1985, 9, :o3, 496803600
          tz.transition 1986, 3, :o4, 512528400
          tz.transition 1986, 9, :o3, 528253200
          tz.transition 1987, 3, :o4, 543978000
          tz.transition 1987, 9, :o3, 559702800
          tz.transition 1988, 3, :o4, 575427600
          tz.transition 1988, 9, :o3, 591152400
          tz.transition 1989, 3, :o4, 606877200
          tz.transition 1989, 9, :o3, 622602000
          tz.transition 1990, 3, :o4, 638326800
          tz.transition 1990, 9, :o3, 654656400
          tz.transition 1991, 3, :o4, 670381200
          tz.transition 1991, 9, :o3, 686106000
          tz.transition 1992, 3, :o4, 701830800
          tz.transition 1992, 9, :o3, 717555600
          tz.transition 1993, 3, :o4, 733280400
          tz.transition 1993, 9, :o3, 749005200
          tz.transition 1994, 3, :o4, 764730000
          tz.transition 1994, 9, :o3, 780454800
          tz.transition 1995, 3, :o4, 796179600
          tz.transition 1995, 9, :o3, 811904400
          tz.transition 1996, 3, :o4, 828234000
          tz.transition 1996, 10, :o3, 846378000
          tz.transition 1997, 3, :o4, 859683600
          tz.transition 1997, 10, :o3, 877827600
          tz.transition 1998, 3, :o4, 891133200
          tz.transition 1998, 10, :o3, 909277200
          tz.transition 1999, 3, :o4, 922582800
          tz.transition 1999, 10, :o3, 941331600
          tz.transition 2000, 3, :o4, 954032400
          tz.transition 2000, 10, :o3, 972781200
          tz.transition 2001, 3, :o4, 985482000
          tz.transition 2001, 10, :o3, 1004230800
          tz.transition 2002, 3, :o4, 1017536400
          tz.transition 2002, 10, :o3, 1035680400
          tz.transition 2003, 3, :o4, 1048986000
          tz.transition 2003, 10, :o3, 1067130000
          tz.transition 2004, 3, :o4, 1080435600
          tz.transition 2004, 10, :o3, 1099184400
          tz.transition 2005, 3, :o4, 1111885200
          tz.transition 2005, 10, :o3, 1130634000
          tz.transition 2006, 3, :o4, 1143334800
          tz.transition 2006, 10, :o3, 1162083600
          tz.transition 2007, 3, :o4, 1174784400
          tz.transition 2007, 10, :o3, 1193533200
          tz.transition 2008, 3, :o4, 1206838800
          tz.transition 2008, 10, :o3, 1224982800
          tz.transition 2009, 3, :o4, 1238288400
          tz.transition 2009, 10, :o3, 1256432400
          tz.transition 2010, 3, :o4, 1269738000
          tz.transition 2010, 10, :o3, 1288486800
          tz.transition 2011, 3, :o4, 1301187600
          tz.transition 2011, 10, :o3, 1319936400
          tz.transition 2012, 3, :o4, 1332637200
          tz.transition 2012, 10, :o3, 1351386000
          tz.transition 2013, 3, :o4, 1364691600
          tz.transition 2013, 10, :o3, 1382835600
          tz.transition 2014, 3, :o4, 1396141200
          tz.transition 2014, 10, :o3, 1414285200
          tz.transition 2015, 3, :o4, 1427590800
          tz.transition 2015, 10, :o3, 1445734800
          tz.transition 2016, 3, :o4, 1459040400
          tz.transition 2016, 10, :o3, 1477789200
          tz.transition 2017, 3, :o4, 1490490000
          tz.transition 2017, 10, :o3, 1509238800
          tz.transition 2018, 3, :o4, 1521939600
          tz.transition 2018, 10, :o3, 1540688400
          tz.transition 2019, 3, :o4, 1553994000
          tz.transition 2019, 10, :o3, 1572138000
          tz.transition 2020, 3, :o4, 1585443600
          tz.transition 2020, 10, :o3, 1603587600
          tz.transition 2021, 3, :o4, 1616893200
          tz.transition 2021, 10, :o3, 1635642000
          tz.transition 2022, 3, :o4, 1648342800
          tz.transition 2022, 10, :o3, 1667091600
          tz.transition 2023, 3, :o4, 1679792400
          tz.transition 2023, 10, :o3, 1698541200
          tz.transition 2024, 3, :o4, 1711846800
          tz.transition 2024, 10, :o3, 1729990800
          tz.transition 2025, 3, :o4, 1743296400
          tz.transition 2025, 10, :o3, 1761440400
          tz.transition 2026, 3, :o4, 1774746000
          tz.transition 2026, 10, :o3, 1792890000
          tz.transition 2027, 3, :o4, 1806195600
          tz.transition 2027, 10, :o3, 1824944400
          tz.transition 2028, 3, :o4, 1837645200
          tz.transition 2028, 10, :o3, 1856394000
          tz.transition 2029, 3, :o4, 1869094800
          tz.transition 2029, 10, :o3, 1887843600
          tz.transition 2030, 3, :o4, 1901149200
          tz.transition 2030, 10, :o3, 1919293200
          tz.transition 2031, 3, :o4, 1932598800
          tz.transition 2031, 10, :o3, 1950742800
          tz.transition 2032, 3, :o4, 1964048400
          tz.transition 2032, 10, :o3, 1982797200
          tz.transition 2033, 3, :o4, 1995498000
          tz.transition 2033, 10, :o3, 2014246800
          tz.transition 2034, 3, :o4, 2026947600
          tz.transition 2034, 10, :o3, 2045696400
          tz.transition 2035, 3, :o4, 2058397200
          tz.transition 2035, 10, :o3, 2077146000
          tz.transition 2036, 3, :o4, 2090451600
          tz.transition 2036, 10, :o3, 2108595600
          tz.transition 2037, 3, :o4, 2121901200
          tz.transition 2037, 10, :o3, 2140045200
          tz.transition 2038, 3, :o4, 59172253, 24
          tz.transition 2038, 10, :o3, 59177461, 24
          tz.transition 2039, 3, :o4, 59180989, 24
          tz.transition 2039, 10, :o3, 59186197, 24
          tz.transition 2040, 3, :o4, 59189725, 24
          tz.transition 2040, 10, :o3, 59194933, 24
          tz.transition 2041, 3, :o4, 59198629, 24
          tz.transition 2041, 10, :o3, 59203669, 24
          tz.transition 2042, 3, :o4, 59207365, 24
          tz.transition 2042, 10, :o3, 59212405, 24
          tz.transition 2043, 3, :o4, 59216101, 24
          tz.transition 2043, 10, :o3, 59221141, 24
          tz.transition 2044, 3, :o4, 59224837, 24
          tz.transition 2044, 10, :o3, 59230045, 24
          tz.transition 2045, 3, :o4, 59233573, 24
          tz.transition 2045, 10, :o3, 59238781, 24
          tz.transition 2046, 3, :o4, 59242309, 24
          tz.transition 2046, 10, :o3, 59247517, 24
          tz.transition 2047, 3, :o4, 59251213, 24
          tz.transition 2047, 10, :o3, 59256253, 24
          tz.transition 2048, 3, :o4, 59259949, 24
          tz.transition 2048, 10, :o3, 59264989, 24
          tz.transition 2049, 3, :o4, 59268685, 24
          tz.transition 2049, 10, :o3, 59273893, 24
          tz.transition 2050, 3, :o4, 59277421, 24
          tz.transition 2050, 10, :o3, 59282629, 24
        end
      end
    end
  end
end
