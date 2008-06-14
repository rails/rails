require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Europe
      module Dublin
        include TimezoneDefinition
        
        timezone 'Europe/Dublin' do |tz|
          tz.offset :o0, -1500, 0, :LMT
          tz.offset :o1, -1521, 0, :DMT
          tz.offset :o2, -1521, 3600, :IST
          tz.offset :o3, 0, 0, :GMT
          tz.offset :o4, 0, 3600, :BST
          tz.offset :o5, 0, 3600, :IST
          tz.offset :o6, 3600, 0, :IST
          
          tz.transition 1880, 8, :o1, 693483701, 288
          tz.transition 1916, 5, :o2, 7747214723, 3200
          tz.transition 1916, 10, :o3, 7747640323, 3200
          tz.transition 1917, 4, :o4, 29055919, 12
          tz.transition 1917, 9, :o3, 29057863, 12
          tz.transition 1918, 3, :o4, 29060119, 12
          tz.transition 1918, 9, :o3, 29062399, 12
          tz.transition 1919, 3, :o4, 29064571, 12
          tz.transition 1919, 9, :o3, 29066767, 12
          tz.transition 1920, 3, :o4, 29068939, 12
          tz.transition 1920, 10, :o3, 29071471, 12
          tz.transition 1921, 4, :o4, 29073391, 12
          tz.transition 1921, 10, :o3, 29075587, 12
          tz.transition 1922, 3, :o5, 29077675, 12
          tz.transition 1922, 10, :o3, 29080027, 12
          tz.transition 1923, 4, :o5, 29082379, 12
          tz.transition 1923, 9, :o3, 29084143, 12
          tz.transition 1924, 4, :o5, 29086663, 12
          tz.transition 1924, 9, :o3, 29088595, 12
          tz.transition 1925, 4, :o5, 29091115, 12
          tz.transition 1925, 10, :o3, 29093131, 12
          tz.transition 1926, 4, :o5, 29095483, 12
          tz.transition 1926, 10, :o3, 29097499, 12
          tz.transition 1927, 4, :o5, 29099767, 12
          tz.transition 1927, 10, :o3, 29101867, 12
          tz.transition 1928, 4, :o5, 29104303, 12
          tz.transition 1928, 10, :o3, 29106319, 12
          tz.transition 1929, 4, :o5, 29108671, 12
          tz.transition 1929, 10, :o3, 29110687, 12
          tz.transition 1930, 4, :o5, 29112955, 12
          tz.transition 1930, 10, :o3, 29115055, 12
          tz.transition 1931, 4, :o5, 29117407, 12
          tz.transition 1931, 10, :o3, 29119423, 12
          tz.transition 1932, 4, :o5, 29121775, 12
          tz.transition 1932, 10, :o3, 29123791, 12
          tz.transition 1933, 4, :o5, 29126059, 12
          tz.transition 1933, 10, :o3, 29128243, 12
          tz.transition 1934, 4, :o5, 29130595, 12
          tz.transition 1934, 10, :o3, 29132611, 12
          tz.transition 1935, 4, :o5, 29134879, 12
          tz.transition 1935, 10, :o3, 29136979, 12
          tz.transition 1936, 4, :o5, 29139331, 12
          tz.transition 1936, 10, :o3, 29141347, 12
          tz.transition 1937, 4, :o5, 29143699, 12
          tz.transition 1937, 10, :o3, 29145715, 12
          tz.transition 1938, 4, :o5, 29147983, 12
          tz.transition 1938, 10, :o3, 29150083, 12
          tz.transition 1939, 4, :o5, 29152435, 12
          tz.transition 1939, 11, :o3, 29155039, 12
          tz.transition 1940, 2, :o5, 29156215, 12
          tz.transition 1946, 10, :o3, 58370389, 24
          tz.transition 1947, 3, :o5, 29187127, 12
          tz.transition 1947, 11, :o3, 58379797, 24
          tz.transition 1948, 4, :o5, 29191915, 12
          tz.transition 1948, 10, :o3, 29194267, 12
          tz.transition 1949, 4, :o5, 29196115, 12
          tz.transition 1949, 10, :o3, 29198635, 12
          tz.transition 1950, 4, :o5, 29200651, 12
          tz.transition 1950, 10, :o3, 29202919, 12
          tz.transition 1951, 4, :o5, 29205019, 12
          tz.transition 1951, 10, :o3, 29207287, 12
          tz.transition 1952, 4, :o5, 29209471, 12
          tz.transition 1952, 10, :o3, 29211739, 12
          tz.transition 1953, 4, :o5, 29213839, 12
          tz.transition 1953, 10, :o3, 29215855, 12
          tz.transition 1954, 4, :o5, 29218123, 12
          tz.transition 1954, 10, :o3, 29220223, 12
          tz.transition 1955, 4, :o5, 29222575, 12
          tz.transition 1955, 10, :o3, 29224591, 12
          tz.transition 1956, 4, :o5, 29227027, 12
          tz.transition 1956, 10, :o3, 29229043, 12
          tz.transition 1957, 4, :o5, 29231311, 12
          tz.transition 1957, 10, :o3, 29233411, 12
          tz.transition 1958, 4, :o5, 29235763, 12
          tz.transition 1958, 10, :o3, 29237779, 12
          tz.transition 1959, 4, :o5, 29240131, 12
          tz.transition 1959, 10, :o3, 29242147, 12
          tz.transition 1960, 4, :o5, 29244415, 12
          tz.transition 1960, 10, :o3, 29246515, 12
          tz.transition 1961, 3, :o5, 29248615, 12
          tz.transition 1961, 10, :o3, 29251219, 12
          tz.transition 1962, 3, :o5, 29252983, 12
          tz.transition 1962, 10, :o3, 29255587, 12
          tz.transition 1963, 3, :o5, 29257435, 12
          tz.transition 1963, 10, :o3, 29259955, 12
          tz.transition 1964, 3, :o5, 29261719, 12
          tz.transition 1964, 10, :o3, 29264323, 12
          tz.transition 1965, 3, :o5, 29266087, 12
          tz.transition 1965, 10, :o3, 29268691, 12
          tz.transition 1966, 3, :o5, 29270455, 12
          tz.transition 1966, 10, :o3, 29273059, 12
          tz.transition 1967, 3, :o5, 29274823, 12
          tz.transition 1967, 10, :o3, 29277511, 12
          tz.transition 1968, 2, :o5, 29278855, 12
          tz.transition 1968, 10, :o6, 58563755, 24
          tz.transition 1971, 10, :o3, 57722400
          tz.transition 1972, 3, :o5, 69818400
          tz.transition 1972, 10, :o3, 89172000
          tz.transition 1973, 3, :o5, 101268000
          tz.transition 1973, 10, :o3, 120621600
          tz.transition 1974, 3, :o5, 132717600
          tz.transition 1974, 10, :o3, 152071200
          tz.transition 1975, 3, :o5, 164167200
          tz.transition 1975, 10, :o3, 183520800
          tz.transition 1976, 3, :o5, 196221600
          tz.transition 1976, 10, :o3, 214970400
          tz.transition 1977, 3, :o5, 227671200
          tz.transition 1977, 10, :o3, 246420000
          tz.transition 1978, 3, :o5, 259120800
          tz.transition 1978, 10, :o3, 278474400
          tz.transition 1979, 3, :o5, 290570400
          tz.transition 1979, 10, :o3, 309924000
          tz.transition 1980, 3, :o5, 322020000
          tz.transition 1980, 10, :o3, 341373600
          tz.transition 1981, 3, :o5, 354675600
          tz.transition 1981, 10, :o3, 372819600
          tz.transition 1982, 3, :o5, 386125200
          tz.transition 1982, 10, :o3, 404269200
          tz.transition 1983, 3, :o5, 417574800
          tz.transition 1983, 10, :o3, 435718800
          tz.transition 1984, 3, :o5, 449024400
          tz.transition 1984, 10, :o3, 467773200
          tz.transition 1985, 3, :o5, 481078800
          tz.transition 1985, 10, :o3, 499222800
          tz.transition 1986, 3, :o5, 512528400
          tz.transition 1986, 10, :o3, 530672400
          tz.transition 1987, 3, :o5, 543978000
          tz.transition 1987, 10, :o3, 562122000
          tz.transition 1988, 3, :o5, 575427600
          tz.transition 1988, 10, :o3, 593571600
          tz.transition 1989, 3, :o5, 606877200
          tz.transition 1989, 10, :o3, 625626000
          tz.transition 1990, 3, :o5, 638326800
          tz.transition 1990, 10, :o3, 657075600
          tz.transition 1991, 3, :o5, 670381200
          tz.transition 1991, 10, :o3, 688525200
          tz.transition 1992, 3, :o5, 701830800
          tz.transition 1992, 10, :o3, 719974800
          tz.transition 1993, 3, :o5, 733280400
          tz.transition 1993, 10, :o3, 751424400
          tz.transition 1994, 3, :o5, 764730000
          tz.transition 1994, 10, :o3, 782874000
          tz.transition 1995, 3, :o5, 796179600
          tz.transition 1995, 10, :o3, 814323600
          tz.transition 1996, 3, :o5, 828234000
          tz.transition 1996, 10, :o3, 846378000
          tz.transition 1997, 3, :o5, 859683600
          tz.transition 1997, 10, :o3, 877827600
          tz.transition 1998, 3, :o5, 891133200
          tz.transition 1998, 10, :o3, 909277200
          tz.transition 1999, 3, :o5, 922582800
          tz.transition 1999, 10, :o3, 941331600
          tz.transition 2000, 3, :o5, 954032400
          tz.transition 2000, 10, :o3, 972781200
          tz.transition 2001, 3, :o5, 985482000
          tz.transition 2001, 10, :o3, 1004230800
          tz.transition 2002, 3, :o5, 1017536400
          tz.transition 2002, 10, :o3, 1035680400
          tz.transition 2003, 3, :o5, 1048986000
          tz.transition 2003, 10, :o3, 1067130000
          tz.transition 2004, 3, :o5, 1080435600
          tz.transition 2004, 10, :o3, 1099184400
          tz.transition 2005, 3, :o5, 1111885200
          tz.transition 2005, 10, :o3, 1130634000
          tz.transition 2006, 3, :o5, 1143334800
          tz.transition 2006, 10, :o3, 1162083600
          tz.transition 2007, 3, :o5, 1174784400
          tz.transition 2007, 10, :o3, 1193533200
          tz.transition 2008, 3, :o5, 1206838800
          tz.transition 2008, 10, :o3, 1224982800
          tz.transition 2009, 3, :o5, 1238288400
          tz.transition 2009, 10, :o3, 1256432400
          tz.transition 2010, 3, :o5, 1269738000
          tz.transition 2010, 10, :o3, 1288486800
          tz.transition 2011, 3, :o5, 1301187600
          tz.transition 2011, 10, :o3, 1319936400
          tz.transition 2012, 3, :o5, 1332637200
          tz.transition 2012, 10, :o3, 1351386000
          tz.transition 2013, 3, :o5, 1364691600
          tz.transition 2013, 10, :o3, 1382835600
          tz.transition 2014, 3, :o5, 1396141200
          tz.transition 2014, 10, :o3, 1414285200
          tz.transition 2015, 3, :o5, 1427590800
          tz.transition 2015, 10, :o3, 1445734800
          tz.transition 2016, 3, :o5, 1459040400
          tz.transition 2016, 10, :o3, 1477789200
          tz.transition 2017, 3, :o5, 1490490000
          tz.transition 2017, 10, :o3, 1509238800
          tz.transition 2018, 3, :o5, 1521939600
          tz.transition 2018, 10, :o3, 1540688400
          tz.transition 2019, 3, :o5, 1553994000
          tz.transition 2019, 10, :o3, 1572138000
          tz.transition 2020, 3, :o5, 1585443600
          tz.transition 2020, 10, :o3, 1603587600
          tz.transition 2021, 3, :o5, 1616893200
          tz.transition 2021, 10, :o3, 1635642000
          tz.transition 2022, 3, :o5, 1648342800
          tz.transition 2022, 10, :o3, 1667091600
          tz.transition 2023, 3, :o5, 1679792400
          tz.transition 2023, 10, :o3, 1698541200
          tz.transition 2024, 3, :o5, 1711846800
          tz.transition 2024, 10, :o3, 1729990800
          tz.transition 2025, 3, :o5, 1743296400
          tz.transition 2025, 10, :o3, 1761440400
          tz.transition 2026, 3, :o5, 1774746000
          tz.transition 2026, 10, :o3, 1792890000
          tz.transition 2027, 3, :o5, 1806195600
          tz.transition 2027, 10, :o3, 1824944400
          tz.transition 2028, 3, :o5, 1837645200
          tz.transition 2028, 10, :o3, 1856394000
          tz.transition 2029, 3, :o5, 1869094800
          tz.transition 2029, 10, :o3, 1887843600
          tz.transition 2030, 3, :o5, 1901149200
          tz.transition 2030, 10, :o3, 1919293200
          tz.transition 2031, 3, :o5, 1932598800
          tz.transition 2031, 10, :o3, 1950742800
          tz.transition 2032, 3, :o5, 1964048400
          tz.transition 2032, 10, :o3, 1982797200
          tz.transition 2033, 3, :o5, 1995498000
          tz.transition 2033, 10, :o3, 2014246800
          tz.transition 2034, 3, :o5, 2026947600
          tz.transition 2034, 10, :o3, 2045696400
          tz.transition 2035, 3, :o5, 2058397200
          tz.transition 2035, 10, :o3, 2077146000
          tz.transition 2036, 3, :o5, 2090451600
          tz.transition 2036, 10, :o3, 2108595600
          tz.transition 2037, 3, :o5, 2121901200
          tz.transition 2037, 10, :o3, 2140045200
          tz.transition 2038, 3, :o5, 59172253, 24
          tz.transition 2038, 10, :o3, 59177461, 24
          tz.transition 2039, 3, :o5, 59180989, 24
          tz.transition 2039, 10, :o3, 59186197, 24
          tz.transition 2040, 3, :o5, 59189725, 24
          tz.transition 2040, 10, :o3, 59194933, 24
          tz.transition 2041, 3, :o5, 59198629, 24
          tz.transition 2041, 10, :o3, 59203669, 24
          tz.transition 2042, 3, :o5, 59207365, 24
          tz.transition 2042, 10, :o3, 59212405, 24
          tz.transition 2043, 3, :o5, 59216101, 24
          tz.transition 2043, 10, :o3, 59221141, 24
          tz.transition 2044, 3, :o5, 59224837, 24
          tz.transition 2044, 10, :o3, 59230045, 24
          tz.transition 2045, 3, :o5, 59233573, 24
          tz.transition 2045, 10, :o3, 59238781, 24
          tz.transition 2046, 3, :o5, 59242309, 24
          tz.transition 2046, 10, :o3, 59247517, 24
          tz.transition 2047, 3, :o5, 59251213, 24
          tz.transition 2047, 10, :o3, 59256253, 24
          tz.transition 2048, 3, :o5, 59259949, 24
          tz.transition 2048, 10, :o3, 59264989, 24
          tz.transition 2049, 3, :o5, 59268685, 24
          tz.transition 2049, 10, :o3, 59273893, 24
          tz.transition 2050, 3, :o5, 59277421, 24
          tz.transition 2050, 10, :o3, 59282629, 24
        end
      end
    end
  end
end
