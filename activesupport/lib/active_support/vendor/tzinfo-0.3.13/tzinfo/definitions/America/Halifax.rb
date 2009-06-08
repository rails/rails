require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module America
      module Halifax
        include TimezoneDefinition
        
        timezone 'America/Halifax' do |tz|
          tz.offset :o0, -15264, 0, :LMT
          tz.offset :o1, -14400, 0, :AST
          tz.offset :o2, -14400, 3600, :ADT
          tz.offset :o3, -14400, 3600, :AWT
          tz.offset :o4, -14400, 3600, :APT
          
          tz.transition 1902, 6, :o1, 724774703, 300
          tz.transition 1916, 4, :o2, 7262864, 3
          tz.transition 1916, 10, :o1, 19369101, 8
          tz.transition 1918, 4, :o2, 9686791, 4
          tz.transition 1918, 10, :o1, 58125545, 24
          tz.transition 1920, 5, :o2, 7267361, 3
          tz.transition 1920, 8, :o1, 19380525, 8
          tz.transition 1921, 5, :o2, 7268447, 3
          tz.transition 1921, 9, :o1, 19383501, 8
          tz.transition 1922, 4, :o2, 7269524, 3
          tz.transition 1922, 9, :o1, 19386421, 8
          tz.transition 1923, 5, :o2, 7270637, 3
          tz.transition 1923, 9, :o1, 19389333, 8
          tz.transition 1924, 5, :o2, 7271729, 3
          tz.transition 1924, 9, :o1, 19392349, 8
          tz.transition 1925, 5, :o2, 7272821, 3
          tz.transition 1925, 9, :o1, 19395373, 8
          tz.transition 1926, 5, :o2, 7273955, 3
          tz.transition 1926, 9, :o1, 19398173, 8
          tz.transition 1927, 5, :o2, 7275005, 3
          tz.transition 1927, 9, :o1, 19401197, 8
          tz.transition 1928, 5, :o2, 7276139, 3
          tz.transition 1928, 9, :o1, 19403989, 8
          tz.transition 1929, 5, :o2, 7277231, 3
          tz.transition 1929, 9, :o1, 19406861, 8
          tz.transition 1930, 5, :o2, 7278323, 3
          tz.transition 1930, 9, :o1, 19409877, 8
          tz.transition 1931, 5, :o2, 7279415, 3
          tz.transition 1931, 9, :o1, 19412901, 8
          tz.transition 1932, 5, :o2, 7280486, 3
          tz.transition 1932, 9, :o1, 19415813, 8
          tz.transition 1933, 4, :o2, 7281578, 3
          tz.transition 1933, 10, :o1, 19418781, 8
          tz.transition 1934, 5, :o2, 7282733, 3
          tz.transition 1934, 9, :o1, 19421573, 8
          tz.transition 1935, 6, :o2, 7283867, 3
          tz.transition 1935, 9, :o1, 19424605, 8
          tz.transition 1936, 6, :o2, 7284962, 3
          tz.transition 1936, 9, :o1, 19427405, 8
          tz.transition 1937, 5, :o2, 7285967, 3
          tz.transition 1937, 9, :o1, 19430429, 8
          tz.transition 1938, 5, :o2, 7287059, 3
          tz.transition 1938, 9, :o1, 19433341, 8
          tz.transition 1939, 5, :o2, 7288235, 3
          tz.transition 1939, 9, :o1, 19436253, 8
          tz.transition 1940, 5, :o2, 7289264, 3
          tz.transition 1940, 9, :o1, 19439221, 8
          tz.transition 1941, 5, :o2, 7290356, 3
          tz.transition 1941, 9, :o1, 19442133, 8
          tz.transition 1942, 2, :o3, 9721599, 4
          tz.transition 1945, 8, :o4, 58360379, 24
          tz.transition 1945, 9, :o1, 58361489, 24
          tz.transition 1946, 4, :o2, 9727755, 4
          tz.transition 1946, 9, :o1, 58370225, 24
          tz.transition 1947, 4, :o2, 9729211, 4
          tz.transition 1947, 9, :o1, 58378961, 24
          tz.transition 1948, 4, :o2, 9730667, 4
          tz.transition 1948, 9, :o1, 58387697, 24
          tz.transition 1949, 4, :o2, 9732123, 4
          tz.transition 1949, 9, :o1, 58396433, 24
          tz.transition 1951, 4, :o2, 9735063, 4
          tz.transition 1951, 9, :o1, 58414073, 24
          tz.transition 1952, 4, :o2, 9736519, 4
          tz.transition 1952, 9, :o1, 58422809, 24
          tz.transition 1953, 4, :o2, 9737975, 4
          tz.transition 1953, 9, :o1, 58431545, 24
          tz.transition 1954, 4, :o2, 9739431, 4
          tz.transition 1954, 9, :o1, 58440281, 24
          tz.transition 1956, 4, :o2, 9742371, 4
          tz.transition 1956, 9, :o1, 58457921, 24
          tz.transition 1957, 4, :o2, 9743827, 4
          tz.transition 1957, 9, :o1, 58466657, 24
          tz.transition 1958, 4, :o2, 9745283, 4
          tz.transition 1958, 9, :o1, 58475393, 24
          tz.transition 1959, 4, :o2, 9746739, 4
          tz.transition 1959, 9, :o1, 58484129, 24
          tz.transition 1962, 4, :o2, 9751135, 4
          tz.transition 1962, 10, :o1, 58511177, 24
          tz.transition 1963, 4, :o2, 9752591, 4
          tz.transition 1963, 10, :o1, 58519913, 24
          tz.transition 1964, 4, :o2, 9754047, 4
          tz.transition 1964, 10, :o1, 58528649, 24
          tz.transition 1965, 4, :o2, 9755503, 4
          tz.transition 1965, 10, :o1, 58537553, 24
          tz.transition 1966, 4, :o2, 9756959, 4
          tz.transition 1966, 10, :o1, 58546289, 24
          tz.transition 1967, 4, :o2, 9758443, 4
          tz.transition 1967, 10, :o1, 58555025, 24
          tz.transition 1968, 4, :o2, 9759899, 4
          tz.transition 1968, 10, :o1, 58563761, 24
          tz.transition 1969, 4, :o2, 9761355, 4
          tz.transition 1969, 10, :o1, 58572497, 24
          tz.transition 1970, 4, :o2, 9957600
          tz.transition 1970, 10, :o1, 25678800
          tz.transition 1971, 4, :o2, 41407200
          tz.transition 1971, 10, :o1, 57733200
          tz.transition 1972, 4, :o2, 73461600
          tz.transition 1972, 10, :o1, 89182800
          tz.transition 1973, 4, :o2, 104911200
          tz.transition 1973, 10, :o1, 120632400
          tz.transition 1974, 4, :o2, 136360800
          tz.transition 1974, 10, :o1, 152082000
          tz.transition 1975, 4, :o2, 167810400
          tz.transition 1975, 10, :o1, 183531600
          tz.transition 1976, 4, :o2, 199260000
          tz.transition 1976, 10, :o1, 215586000
          tz.transition 1977, 4, :o2, 230709600
          tz.transition 1977, 10, :o1, 247035600
          tz.transition 1978, 4, :o2, 262764000
          tz.transition 1978, 10, :o1, 278485200
          tz.transition 1979, 4, :o2, 294213600
          tz.transition 1979, 10, :o1, 309934800
          tz.transition 1980, 4, :o2, 325663200
          tz.transition 1980, 10, :o1, 341384400
          tz.transition 1981, 4, :o2, 357112800
          tz.transition 1981, 10, :o1, 372834000
          tz.transition 1982, 4, :o2, 388562400
          tz.transition 1982, 10, :o1, 404888400
          tz.transition 1983, 4, :o2, 420012000
          tz.transition 1983, 10, :o1, 436338000
          tz.transition 1984, 4, :o2, 452066400
          tz.transition 1984, 10, :o1, 467787600
          tz.transition 1985, 4, :o2, 483516000
          tz.transition 1985, 10, :o1, 499237200
          tz.transition 1986, 4, :o2, 514965600
          tz.transition 1986, 10, :o1, 530686800
          tz.transition 1987, 4, :o2, 544600800
          tz.transition 1987, 10, :o1, 562136400
          tz.transition 1988, 4, :o2, 576050400
          tz.transition 1988, 10, :o1, 594190800
          tz.transition 1989, 4, :o2, 607500000
          tz.transition 1989, 10, :o1, 625640400
          tz.transition 1990, 4, :o2, 638949600
          tz.transition 1990, 10, :o1, 657090000
          tz.transition 1991, 4, :o2, 671004000
          tz.transition 1991, 10, :o1, 688539600
          tz.transition 1992, 4, :o2, 702453600
          tz.transition 1992, 10, :o1, 719989200
          tz.transition 1993, 4, :o2, 733903200
          tz.transition 1993, 10, :o1, 752043600
          tz.transition 1994, 4, :o2, 765352800
          tz.transition 1994, 10, :o1, 783493200
          tz.transition 1995, 4, :o2, 796802400
          tz.transition 1995, 10, :o1, 814942800
          tz.transition 1996, 4, :o2, 828856800
          tz.transition 1996, 10, :o1, 846392400
          tz.transition 1997, 4, :o2, 860306400
          tz.transition 1997, 10, :o1, 877842000
          tz.transition 1998, 4, :o2, 891756000
          tz.transition 1998, 10, :o1, 909291600
          tz.transition 1999, 4, :o2, 923205600
          tz.transition 1999, 10, :o1, 941346000
          tz.transition 2000, 4, :o2, 954655200
          tz.transition 2000, 10, :o1, 972795600
          tz.transition 2001, 4, :o2, 986104800
          tz.transition 2001, 10, :o1, 1004245200
          tz.transition 2002, 4, :o2, 1018159200
          tz.transition 2002, 10, :o1, 1035694800
          tz.transition 2003, 4, :o2, 1049608800
          tz.transition 2003, 10, :o1, 1067144400
          tz.transition 2004, 4, :o2, 1081058400
          tz.transition 2004, 10, :o1, 1099198800
          tz.transition 2005, 4, :o2, 1112508000
          tz.transition 2005, 10, :o1, 1130648400
          tz.transition 2006, 4, :o2, 1143957600
          tz.transition 2006, 10, :o1, 1162098000
          tz.transition 2007, 3, :o2, 1173592800
          tz.transition 2007, 11, :o1, 1194152400
          tz.transition 2008, 3, :o2, 1205042400
          tz.transition 2008, 11, :o1, 1225602000
          tz.transition 2009, 3, :o2, 1236492000
          tz.transition 2009, 11, :o1, 1257051600
          tz.transition 2010, 3, :o2, 1268546400
          tz.transition 2010, 11, :o1, 1289106000
          tz.transition 2011, 3, :o2, 1299996000
          tz.transition 2011, 11, :o1, 1320555600
          tz.transition 2012, 3, :o2, 1331445600
          tz.transition 2012, 11, :o1, 1352005200
          tz.transition 2013, 3, :o2, 1362895200
          tz.transition 2013, 11, :o1, 1383454800
          tz.transition 2014, 3, :o2, 1394344800
          tz.transition 2014, 11, :o1, 1414904400
          tz.transition 2015, 3, :o2, 1425794400
          tz.transition 2015, 11, :o1, 1446354000
          tz.transition 2016, 3, :o2, 1457848800
          tz.transition 2016, 11, :o1, 1478408400
          tz.transition 2017, 3, :o2, 1489298400
          tz.transition 2017, 11, :o1, 1509858000
          tz.transition 2018, 3, :o2, 1520748000
          tz.transition 2018, 11, :o1, 1541307600
          tz.transition 2019, 3, :o2, 1552197600
          tz.transition 2019, 11, :o1, 1572757200
          tz.transition 2020, 3, :o2, 1583647200
          tz.transition 2020, 11, :o1, 1604206800
          tz.transition 2021, 3, :o2, 1615701600
          tz.transition 2021, 11, :o1, 1636261200
          tz.transition 2022, 3, :o2, 1647151200
          tz.transition 2022, 11, :o1, 1667710800
          tz.transition 2023, 3, :o2, 1678600800
          tz.transition 2023, 11, :o1, 1699160400
          tz.transition 2024, 3, :o2, 1710050400
          tz.transition 2024, 11, :o1, 1730610000
          tz.transition 2025, 3, :o2, 1741500000
          tz.transition 2025, 11, :o1, 1762059600
          tz.transition 2026, 3, :o2, 1772949600
          tz.transition 2026, 11, :o1, 1793509200
          tz.transition 2027, 3, :o2, 1805004000
          tz.transition 2027, 11, :o1, 1825563600
          tz.transition 2028, 3, :o2, 1836453600
          tz.transition 2028, 11, :o1, 1857013200
          tz.transition 2029, 3, :o2, 1867903200
          tz.transition 2029, 11, :o1, 1888462800
          tz.transition 2030, 3, :o2, 1899352800
          tz.transition 2030, 11, :o1, 1919912400
          tz.transition 2031, 3, :o2, 1930802400
          tz.transition 2031, 11, :o1, 1951362000
          tz.transition 2032, 3, :o2, 1962856800
          tz.transition 2032, 11, :o1, 1983416400
          tz.transition 2033, 3, :o2, 1994306400
          tz.transition 2033, 11, :o1, 2014866000
          tz.transition 2034, 3, :o2, 2025756000
          tz.transition 2034, 11, :o1, 2046315600
          tz.transition 2035, 3, :o2, 2057205600
          tz.transition 2035, 11, :o1, 2077765200
          tz.transition 2036, 3, :o2, 2088655200
          tz.transition 2036, 11, :o1, 2109214800
          tz.transition 2037, 3, :o2, 2120104800
          tz.transition 2037, 11, :o1, 2140664400
          tz.transition 2038, 3, :o2, 9861987, 4
          tz.transition 2038, 11, :o1, 59177633, 24
          tz.transition 2039, 3, :o2, 9863443, 4
          tz.transition 2039, 11, :o1, 59186369, 24
          tz.transition 2040, 3, :o2, 9864899, 4
          tz.transition 2040, 11, :o1, 59195105, 24
          tz.transition 2041, 3, :o2, 9866355, 4
          tz.transition 2041, 11, :o1, 59203841, 24
          tz.transition 2042, 3, :o2, 9867811, 4
          tz.transition 2042, 11, :o1, 59212577, 24
          tz.transition 2043, 3, :o2, 9869267, 4
          tz.transition 2043, 11, :o1, 59221313, 24
          tz.transition 2044, 3, :o2, 9870751, 4
          tz.transition 2044, 11, :o1, 59230217, 24
          tz.transition 2045, 3, :o2, 9872207, 4
          tz.transition 2045, 11, :o1, 59238953, 24
          tz.transition 2046, 3, :o2, 9873663, 4
          tz.transition 2046, 11, :o1, 59247689, 24
          tz.transition 2047, 3, :o2, 9875119, 4
          tz.transition 2047, 11, :o1, 59256425, 24
          tz.transition 2048, 3, :o2, 9876575, 4
          tz.transition 2048, 11, :o1, 59265161, 24
          tz.transition 2049, 3, :o2, 9878059, 4
          tz.transition 2049, 11, :o1, 59274065, 24
          tz.transition 2050, 3, :o2, 9879515, 4
          tz.transition 2050, 11, :o1, 59282801, 24
        end
      end
    end
  end
end
