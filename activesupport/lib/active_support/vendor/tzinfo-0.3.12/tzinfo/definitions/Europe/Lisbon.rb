require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Europe
      module Lisbon
        include TimezoneDefinition
        
        timezone 'Europe/Lisbon' do |tz|
          tz.offset :o0, -2192, 0, :LMT
          tz.offset :o1, 0, 0, :WET
          tz.offset :o2, 0, 3600, :WEST
          tz.offset :o3, 0, 7200, :WEMT
          tz.offset :o4, 3600, 0, :CET
          tz.offset :o5, 3600, 3600, :CEST
          
          tz.transition 1912, 1, :o1, 13064773637, 5400
          tz.transition 1916, 6, :o2, 58104779, 24
          tz.transition 1916, 11, :o1, 4842337, 2
          tz.transition 1917, 2, :o2, 58110923, 24
          tz.transition 1917, 10, :o1, 58116395, 24
          tz.transition 1918, 3, :o2, 58119707, 24
          tz.transition 1918, 10, :o1, 58125155, 24
          tz.transition 1919, 2, :o2, 58128443, 24
          tz.transition 1919, 10, :o1, 58133915, 24
          tz.transition 1920, 2, :o2, 58137227, 24
          tz.transition 1920, 10, :o1, 58142699, 24
          tz.transition 1921, 2, :o2, 58145987, 24
          tz.transition 1921, 10, :o1, 58151459, 24
          tz.transition 1924, 4, :o2, 58173419, 24
          tz.transition 1924, 10, :o1, 58177763, 24
          tz.transition 1926, 4, :o2, 58190963, 24
          tz.transition 1926, 10, :o1, 58194995, 24
          tz.transition 1927, 4, :o2, 58199531, 24
          tz.transition 1927, 10, :o1, 58203731, 24
          tz.transition 1928, 4, :o2, 58208435, 24
          tz.transition 1928, 10, :o1, 58212635, 24
          tz.transition 1929, 4, :o2, 58217339, 24
          tz.transition 1929, 10, :o1, 58221371, 24
          tz.transition 1931, 4, :o2, 58234811, 24
          tz.transition 1931, 10, :o1, 58238843, 24
          tz.transition 1932, 4, :o2, 58243211, 24
          tz.transition 1932, 10, :o1, 58247579, 24
          tz.transition 1934, 4, :o2, 58260851, 24
          tz.transition 1934, 10, :o1, 58265219, 24
          tz.transition 1935, 3, :o2, 58269419, 24
          tz.transition 1935, 10, :o1, 58273955, 24
          tz.transition 1936, 4, :o2, 58278659, 24
          tz.transition 1936, 10, :o1, 58282691, 24
          tz.transition 1937, 4, :o2, 58287059, 24
          tz.transition 1937, 10, :o1, 58291427, 24
          tz.transition 1938, 3, :o2, 58295627, 24
          tz.transition 1938, 10, :o1, 58300163, 24
          tz.transition 1939, 4, :o2, 58304867, 24
          tz.transition 1939, 11, :o1, 58310075, 24
          tz.transition 1940, 2, :o2, 58312427, 24
          tz.transition 1940, 10, :o1, 58317803, 24
          tz.transition 1941, 4, :o2, 58322171, 24
          tz.transition 1941, 10, :o1, 58326563, 24
          tz.transition 1942, 3, :o2, 58330403, 24
          tz.transition 1942, 4, :o3, 29165705, 12
          tz.transition 1942, 8, :o2, 29167049, 12
          tz.transition 1942, 10, :o1, 58335779, 24
          tz.transition 1943, 3, :o2, 58339139, 24
          tz.transition 1943, 4, :o3, 29169989, 12
          tz.transition 1943, 8, :o2, 29171585, 12
          tz.transition 1943, 10, :o1, 58344683, 24
          tz.transition 1944, 3, :o2, 58347875, 24
          tz.transition 1944, 4, :o3, 29174441, 12
          tz.transition 1944, 8, :o2, 29175953, 12
          tz.transition 1944, 10, :o1, 58353419, 24
          tz.transition 1945, 3, :o2, 58356611, 24
          tz.transition 1945, 4, :o3, 29178809, 12
          tz.transition 1945, 8, :o2, 29180321, 12
          tz.transition 1945, 10, :o1, 58362155, 24
          tz.transition 1946, 4, :o2, 58366019, 24
          tz.transition 1946, 10, :o1, 58370387, 24
          tz.transition 1947, 4, :o2, 29187379, 12
          tz.transition 1947, 10, :o1, 29189563, 12
          tz.transition 1948, 4, :o2, 29191747, 12
          tz.transition 1948, 10, :o1, 29193931, 12
          tz.transition 1949, 4, :o2, 29196115, 12
          tz.transition 1949, 10, :o1, 29198299, 12
          tz.transition 1951, 4, :o2, 29204851, 12
          tz.transition 1951, 10, :o1, 29207119, 12
          tz.transition 1952, 4, :o2, 29209303, 12
          tz.transition 1952, 10, :o1, 29211487, 12
          tz.transition 1953, 4, :o2, 29213671, 12
          tz.transition 1953, 10, :o1, 29215855, 12
          tz.transition 1954, 4, :o2, 29218039, 12
          tz.transition 1954, 10, :o1, 29220223, 12
          tz.transition 1955, 4, :o2, 29222407, 12
          tz.transition 1955, 10, :o1, 29224591, 12
          tz.transition 1956, 4, :o2, 29226775, 12
          tz.transition 1956, 10, :o1, 29229043, 12
          tz.transition 1957, 4, :o2, 29231227, 12
          tz.transition 1957, 10, :o1, 29233411, 12
          tz.transition 1958, 4, :o2, 29235595, 12
          tz.transition 1958, 10, :o1, 29237779, 12
          tz.transition 1959, 4, :o2, 29239963, 12
          tz.transition 1959, 10, :o1, 29242147, 12
          tz.transition 1960, 4, :o2, 29244331, 12
          tz.transition 1960, 10, :o1, 29246515, 12
          tz.transition 1961, 4, :o2, 29248699, 12
          tz.transition 1961, 10, :o1, 29250883, 12
          tz.transition 1962, 4, :o2, 29253067, 12
          tz.transition 1962, 10, :o1, 29255335, 12
          tz.transition 1963, 4, :o2, 29257519, 12
          tz.transition 1963, 10, :o1, 29259703, 12
          tz.transition 1964, 4, :o2, 29261887, 12
          tz.transition 1964, 10, :o1, 29264071, 12
          tz.transition 1965, 4, :o2, 29266255, 12
          tz.transition 1965, 10, :o1, 29268439, 12
          tz.transition 1966, 4, :o4, 29270623, 12
          tz.transition 1976, 9, :o1, 212544000
          tz.transition 1977, 3, :o2, 228268800
          tz.transition 1977, 9, :o1, 243993600
          tz.transition 1978, 4, :o2, 260323200
          tz.transition 1978, 10, :o1, 276048000
          tz.transition 1979, 4, :o2, 291772800
          tz.transition 1979, 9, :o1, 307501200
          tz.transition 1980, 3, :o2, 323222400
          tz.transition 1980, 9, :o1, 338950800
          tz.transition 1981, 3, :o2, 354675600
          tz.transition 1981, 9, :o1, 370400400
          tz.transition 1982, 3, :o2, 386125200
          tz.transition 1982, 9, :o1, 401850000
          tz.transition 1983, 3, :o2, 417578400
          tz.transition 1983, 9, :o1, 433299600
          tz.transition 1984, 3, :o2, 449024400
          tz.transition 1984, 9, :o1, 465354000
          tz.transition 1985, 3, :o2, 481078800
          tz.transition 1985, 9, :o1, 496803600
          tz.transition 1986, 3, :o2, 512528400
          tz.transition 1986, 9, :o1, 528253200
          tz.transition 1987, 3, :o2, 543978000
          tz.transition 1987, 9, :o1, 559702800
          tz.transition 1988, 3, :o2, 575427600
          tz.transition 1988, 9, :o1, 591152400
          tz.transition 1989, 3, :o2, 606877200
          tz.transition 1989, 9, :o1, 622602000
          tz.transition 1990, 3, :o2, 638326800
          tz.transition 1990, 9, :o1, 654656400
          tz.transition 1991, 3, :o2, 670381200
          tz.transition 1991, 9, :o1, 686106000
          tz.transition 1992, 3, :o2, 701830800
          tz.transition 1992, 9, :o4, 717555600
          tz.transition 1993, 3, :o5, 733280400
          tz.transition 1993, 9, :o4, 749005200
          tz.transition 1994, 3, :o5, 764730000
          tz.transition 1994, 9, :o4, 780454800
          tz.transition 1995, 3, :o5, 796179600
          tz.transition 1995, 9, :o4, 811904400
          tz.transition 1996, 3, :o2, 828234000
          tz.transition 1996, 10, :o1, 846378000
          tz.transition 1997, 3, :o2, 859683600
          tz.transition 1997, 10, :o1, 877827600
          tz.transition 1998, 3, :o2, 891133200
          tz.transition 1998, 10, :o1, 909277200
          tz.transition 1999, 3, :o2, 922582800
          tz.transition 1999, 10, :o1, 941331600
          tz.transition 2000, 3, :o2, 954032400
          tz.transition 2000, 10, :o1, 972781200
          tz.transition 2001, 3, :o2, 985482000
          tz.transition 2001, 10, :o1, 1004230800
          tz.transition 2002, 3, :o2, 1017536400
          tz.transition 2002, 10, :o1, 1035680400
          tz.transition 2003, 3, :o2, 1048986000
          tz.transition 2003, 10, :o1, 1067130000
          tz.transition 2004, 3, :o2, 1080435600
          tz.transition 2004, 10, :o1, 1099184400
          tz.transition 2005, 3, :o2, 1111885200
          tz.transition 2005, 10, :o1, 1130634000
          tz.transition 2006, 3, :o2, 1143334800
          tz.transition 2006, 10, :o1, 1162083600
          tz.transition 2007, 3, :o2, 1174784400
          tz.transition 2007, 10, :o1, 1193533200
          tz.transition 2008, 3, :o2, 1206838800
          tz.transition 2008, 10, :o1, 1224982800
          tz.transition 2009, 3, :o2, 1238288400
          tz.transition 2009, 10, :o1, 1256432400
          tz.transition 2010, 3, :o2, 1269738000
          tz.transition 2010, 10, :o1, 1288486800
          tz.transition 2011, 3, :o2, 1301187600
          tz.transition 2011, 10, :o1, 1319936400
          tz.transition 2012, 3, :o2, 1332637200
          tz.transition 2012, 10, :o1, 1351386000
          tz.transition 2013, 3, :o2, 1364691600
          tz.transition 2013, 10, :o1, 1382835600
          tz.transition 2014, 3, :o2, 1396141200
          tz.transition 2014, 10, :o1, 1414285200
          tz.transition 2015, 3, :o2, 1427590800
          tz.transition 2015, 10, :o1, 1445734800
          tz.transition 2016, 3, :o2, 1459040400
          tz.transition 2016, 10, :o1, 1477789200
          tz.transition 2017, 3, :o2, 1490490000
          tz.transition 2017, 10, :o1, 1509238800
          tz.transition 2018, 3, :o2, 1521939600
          tz.transition 2018, 10, :o1, 1540688400
          tz.transition 2019, 3, :o2, 1553994000
          tz.transition 2019, 10, :o1, 1572138000
          tz.transition 2020, 3, :o2, 1585443600
          tz.transition 2020, 10, :o1, 1603587600
          tz.transition 2021, 3, :o2, 1616893200
          tz.transition 2021, 10, :o1, 1635642000
          tz.transition 2022, 3, :o2, 1648342800
          tz.transition 2022, 10, :o1, 1667091600
          tz.transition 2023, 3, :o2, 1679792400
          tz.transition 2023, 10, :o1, 1698541200
          tz.transition 2024, 3, :o2, 1711846800
          tz.transition 2024, 10, :o1, 1729990800
          tz.transition 2025, 3, :o2, 1743296400
          tz.transition 2025, 10, :o1, 1761440400
          tz.transition 2026, 3, :o2, 1774746000
          tz.transition 2026, 10, :o1, 1792890000
          tz.transition 2027, 3, :o2, 1806195600
          tz.transition 2027, 10, :o1, 1824944400
          tz.transition 2028, 3, :o2, 1837645200
          tz.transition 2028, 10, :o1, 1856394000
          tz.transition 2029, 3, :o2, 1869094800
          tz.transition 2029, 10, :o1, 1887843600
          tz.transition 2030, 3, :o2, 1901149200
          tz.transition 2030, 10, :o1, 1919293200
          tz.transition 2031, 3, :o2, 1932598800
          tz.transition 2031, 10, :o1, 1950742800
          tz.transition 2032, 3, :o2, 1964048400
          tz.transition 2032, 10, :o1, 1982797200
          tz.transition 2033, 3, :o2, 1995498000
          tz.transition 2033, 10, :o1, 2014246800
          tz.transition 2034, 3, :o2, 2026947600
          tz.transition 2034, 10, :o1, 2045696400
          tz.transition 2035, 3, :o2, 2058397200
          tz.transition 2035, 10, :o1, 2077146000
          tz.transition 2036, 3, :o2, 2090451600
          tz.transition 2036, 10, :o1, 2108595600
          tz.transition 2037, 3, :o2, 2121901200
          tz.transition 2037, 10, :o1, 2140045200
          tz.transition 2038, 3, :o2, 59172253, 24
          tz.transition 2038, 10, :o1, 59177461, 24
          tz.transition 2039, 3, :o2, 59180989, 24
          tz.transition 2039, 10, :o1, 59186197, 24
          tz.transition 2040, 3, :o2, 59189725, 24
          tz.transition 2040, 10, :o1, 59194933, 24
          tz.transition 2041, 3, :o2, 59198629, 24
          tz.transition 2041, 10, :o1, 59203669, 24
          tz.transition 2042, 3, :o2, 59207365, 24
          tz.transition 2042, 10, :o1, 59212405, 24
          tz.transition 2043, 3, :o2, 59216101, 24
          tz.transition 2043, 10, :o1, 59221141, 24
          tz.transition 2044, 3, :o2, 59224837, 24
          tz.transition 2044, 10, :o1, 59230045, 24
          tz.transition 2045, 3, :o2, 59233573, 24
          tz.transition 2045, 10, :o1, 59238781, 24
          tz.transition 2046, 3, :o2, 59242309, 24
          tz.transition 2046, 10, :o1, 59247517, 24
          tz.transition 2047, 3, :o2, 59251213, 24
          tz.transition 2047, 10, :o1, 59256253, 24
          tz.transition 2048, 3, :o2, 59259949, 24
          tz.transition 2048, 10, :o1, 59264989, 24
          tz.transition 2049, 3, :o2, 59268685, 24
          tz.transition 2049, 10, :o1, 59273893, 24
          tz.transition 2050, 3, :o2, 59277421, 24
          tz.transition 2050, 10, :o1, 59282629, 24
        end
      end
    end
  end
end
