require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module America
      module St_Johns
        include TimezoneDefinition
        
        timezone 'America/St_Johns' do |tz|
          tz.offset :o0, -12652, 0, :LMT
          tz.offset :o1, -12652, 0, :NST
          tz.offset :o2, -12652, 3600, :NDT
          tz.offset :o3, -12600, 0, :NST
          tz.offset :o4, -12600, 3600, :NDT
          tz.offset :o5, -12600, 3600, :NWT
          tz.offset :o6, -12600, 3600, :NPT
          tz.offset :o7, -12600, 7200, :NDDT
          
          tz.transition 1884, 1, :o1, 52038215563, 21600
          tz.transition 1917, 4, :o2, 52300657363, 21600
          tz.transition 1917, 9, :o1, 52304155663, 21600
          tz.transition 1918, 4, :o2, 52308670963, 21600
          tz.transition 1918, 10, :o1, 52312990063, 21600
          tz.transition 1919, 5, :o2, 52317027463, 21600
          tz.transition 1919, 8, :o1, 52319164963, 21600
          tz.transition 1920, 5, :o2, 52324868263, 21600
          tz.transition 1920, 11, :o1, 52328798563, 21600
          tz.transition 1921, 5, :o2, 52332730663, 21600
          tz.transition 1921, 10, :o1, 52336660963, 21600
          tz.transition 1922, 5, :o2, 52340744263, 21600
          tz.transition 1922, 10, :o1, 52344523363, 21600
          tz.transition 1923, 5, :o2, 52348606663, 21600
          tz.transition 1923, 10, :o1, 52352385763, 21600
          tz.transition 1924, 5, :o2, 52356469063, 21600
          tz.transition 1924, 10, :o1, 52360248163, 21600
          tz.transition 1925, 5, :o2, 52364331463, 21600
          tz.transition 1925, 10, :o1, 52368110563, 21600
          tz.transition 1926, 5, :o2, 52372193863, 21600
          tz.transition 1926, 11, :o1, 52376124163, 21600
          tz.transition 1927, 5, :o2, 52380056263, 21600
          tz.transition 1927, 10, :o1, 52383986563, 21600
          tz.transition 1928, 5, :o2, 52388069863, 21600
          tz.transition 1928, 10, :o1, 52391848963, 21600
          tz.transition 1929, 5, :o2, 52395932263, 21600
          tz.transition 1929, 10, :o1, 52399711363, 21600
          tz.transition 1930, 5, :o2, 52403794663, 21600
          tz.transition 1930, 10, :o1, 52407573763, 21600
          tz.transition 1931, 5, :o2, 52411657063, 21600
          tz.transition 1931, 10, :o1, 52415436163, 21600
          tz.transition 1932, 5, :o2, 52419519463, 21600
          tz.transition 1932, 10, :o1, 52423449763, 21600
          tz.transition 1933, 5, :o2, 52427533063, 21600
          tz.transition 1933, 10, :o1, 52431312163, 21600
          tz.transition 1934, 5, :o2, 52435395463, 21600
          tz.transition 1934, 10, :o1, 52439174563, 21600
          tz.transition 1935, 3, :o3, 52442459563, 21600
          tz.transition 1935, 5, :o4, 116540573, 48
          tz.transition 1935, 10, :o3, 38849657, 16
          tz.transition 1936, 5, :o4, 116558383, 48
          tz.transition 1936, 10, :o3, 116565437, 48
          tz.transition 1937, 5, :o4, 116575855, 48
          tz.transition 1937, 10, :o3, 116582909, 48
          tz.transition 1938, 5, :o4, 116593327, 48
          tz.transition 1938, 10, :o3, 116600381, 48
          tz.transition 1939, 5, :o4, 116611135, 48
          tz.transition 1939, 10, :o3, 116617853, 48
          tz.transition 1940, 5, :o4, 116628607, 48
          tz.transition 1940, 10, :o3, 116635661, 48
          tz.transition 1941, 5, :o4, 116646079, 48
          tz.transition 1941, 10, :o3, 116653133, 48
          tz.transition 1942, 5, :o5, 116663551, 48
          tz.transition 1945, 8, :o6, 58360379, 24
          tz.transition 1945, 9, :o3, 38907659, 16
          tz.transition 1946, 5, :o4, 116733731, 48
          tz.transition 1946, 10, :o3, 38913595, 16
          tz.transition 1947, 5, :o4, 116751203, 48
          tz.transition 1947, 10, :o3, 38919419, 16
          tz.transition 1948, 5, :o4, 116768675, 48
          tz.transition 1948, 10, :o3, 38925243, 16
          tz.transition 1949, 5, :o4, 116786147, 48
          tz.transition 1949, 10, :o3, 38931067, 16
          tz.transition 1950, 5, :o4, 116803955, 48
          tz.transition 1950, 10, :o3, 38937003, 16
          tz.transition 1951, 4, :o4, 116820755, 48
          tz.transition 1951, 9, :o3, 38942715, 16
          tz.transition 1952, 4, :o4, 116838227, 48
          tz.transition 1952, 9, :o3, 38948539, 16
          tz.transition 1953, 4, :o4, 116855699, 48
          tz.transition 1953, 9, :o3, 38954363, 16
          tz.transition 1954, 4, :o4, 116873171, 48
          tz.transition 1954, 9, :o3, 38960187, 16
          tz.transition 1955, 4, :o4, 116890643, 48
          tz.transition 1955, 9, :o3, 38966011, 16
          tz.transition 1956, 4, :o4, 116908451, 48
          tz.transition 1956, 9, :o3, 38971947, 16
          tz.transition 1957, 4, :o4, 116925923, 48
          tz.transition 1957, 9, :o3, 38977771, 16
          tz.transition 1958, 4, :o4, 116943395, 48
          tz.transition 1958, 9, :o3, 38983595, 16
          tz.transition 1959, 4, :o4, 116960867, 48
          tz.transition 1959, 9, :o3, 38989419, 16
          tz.transition 1960, 4, :o4, 116978339, 48
          tz.transition 1960, 10, :o3, 38995803, 16
          tz.transition 1961, 4, :o4, 116996147, 48
          tz.transition 1961, 10, :o3, 39001627, 16
          tz.transition 1962, 4, :o4, 117013619, 48
          tz.transition 1962, 10, :o3, 39007451, 16
          tz.transition 1963, 4, :o4, 117031091, 48
          tz.transition 1963, 10, :o3, 39013275, 16
          tz.transition 1964, 4, :o4, 117048563, 48
          tz.transition 1964, 10, :o3, 39019099, 16
          tz.transition 1965, 4, :o4, 117066035, 48
          tz.transition 1965, 10, :o3, 39025035, 16
          tz.transition 1966, 4, :o4, 117083507, 48
          tz.transition 1966, 10, :o3, 39030859, 16
          tz.transition 1967, 4, :o4, 117101315, 48
          tz.transition 1967, 10, :o3, 39036683, 16
          tz.transition 1968, 4, :o4, 117118787, 48
          tz.transition 1968, 10, :o3, 39042507, 16
          tz.transition 1969, 4, :o4, 117136259, 48
          tz.transition 1969, 10, :o3, 39048331, 16
          tz.transition 1970, 4, :o4, 9955800
          tz.transition 1970, 10, :o3, 25677000
          tz.transition 1971, 4, :o4, 41405400
          tz.transition 1971, 10, :o3, 57731400
          tz.transition 1972, 4, :o4, 73459800
          tz.transition 1972, 10, :o3, 89181000
          tz.transition 1973, 4, :o4, 104909400
          tz.transition 1973, 10, :o3, 120630600
          tz.transition 1974, 4, :o4, 136359000
          tz.transition 1974, 10, :o3, 152080200
          tz.transition 1975, 4, :o4, 167808600
          tz.transition 1975, 10, :o3, 183529800
          tz.transition 1976, 4, :o4, 199258200
          tz.transition 1976, 10, :o3, 215584200
          tz.transition 1977, 4, :o4, 230707800
          tz.transition 1977, 10, :o3, 247033800
          tz.transition 1978, 4, :o4, 262762200
          tz.transition 1978, 10, :o3, 278483400
          tz.transition 1979, 4, :o4, 294211800
          tz.transition 1979, 10, :o3, 309933000
          tz.transition 1980, 4, :o4, 325661400
          tz.transition 1980, 10, :o3, 341382600
          tz.transition 1981, 4, :o4, 357111000
          tz.transition 1981, 10, :o3, 372832200
          tz.transition 1982, 4, :o4, 388560600
          tz.transition 1982, 10, :o3, 404886600
          tz.transition 1983, 4, :o4, 420010200
          tz.transition 1983, 10, :o3, 436336200
          tz.transition 1984, 4, :o4, 452064600
          tz.transition 1984, 10, :o3, 467785800
          tz.transition 1985, 4, :o4, 483514200
          tz.transition 1985, 10, :o3, 499235400
          tz.transition 1986, 4, :o4, 514963800
          tz.transition 1986, 10, :o3, 530685000
          tz.transition 1987, 4, :o4, 544591860
          tz.transition 1987, 10, :o3, 562127460
          tz.transition 1988, 4, :o7, 576041460
          tz.transition 1988, 10, :o3, 594178260
          tz.transition 1989, 4, :o4, 607491060
          tz.transition 1989, 10, :o3, 625631460
          tz.transition 1990, 4, :o4, 638940660
          tz.transition 1990, 10, :o3, 657081060
          tz.transition 1991, 4, :o4, 670995060
          tz.transition 1991, 10, :o3, 688530660
          tz.transition 1992, 4, :o4, 702444660
          tz.transition 1992, 10, :o3, 719980260
          tz.transition 1993, 4, :o4, 733894260
          tz.transition 1993, 10, :o3, 752034660
          tz.transition 1994, 4, :o4, 765343860
          tz.transition 1994, 10, :o3, 783484260
          tz.transition 1995, 4, :o4, 796793460
          tz.transition 1995, 10, :o3, 814933860
          tz.transition 1996, 4, :o4, 828847860
          tz.transition 1996, 10, :o3, 846383460
          tz.transition 1997, 4, :o4, 860297460
          tz.transition 1997, 10, :o3, 877833060
          tz.transition 1998, 4, :o4, 891747060
          tz.transition 1998, 10, :o3, 909282660
          tz.transition 1999, 4, :o4, 923196660
          tz.transition 1999, 10, :o3, 941337060
          tz.transition 2000, 4, :o4, 954646260
          tz.transition 2000, 10, :o3, 972786660
          tz.transition 2001, 4, :o4, 986095860
          tz.transition 2001, 10, :o3, 1004236260
          tz.transition 2002, 4, :o4, 1018150260
          tz.transition 2002, 10, :o3, 1035685860
          tz.transition 2003, 4, :o4, 1049599860
          tz.transition 2003, 10, :o3, 1067135460
          tz.transition 2004, 4, :o4, 1081049460
          tz.transition 2004, 10, :o3, 1099189860
          tz.transition 2005, 4, :o4, 1112499060
          tz.transition 2005, 10, :o3, 1130639460
          tz.transition 2006, 4, :o4, 1143948660
          tz.transition 2006, 10, :o3, 1162089060
          tz.transition 2007, 3, :o4, 1173583860
          tz.transition 2007, 11, :o3, 1194143460
          tz.transition 2008, 3, :o4, 1205033460
          tz.transition 2008, 11, :o3, 1225593060
          tz.transition 2009, 3, :o4, 1236483060
          tz.transition 2009, 11, :o3, 1257042660
          tz.transition 2010, 3, :o4, 1268537460
          tz.transition 2010, 11, :o3, 1289097060
          tz.transition 2011, 3, :o4, 1299987060
          tz.transition 2011, 11, :o3, 1320546660
          tz.transition 2012, 3, :o4, 1331436660
          tz.transition 2012, 11, :o3, 1351996260
          tz.transition 2013, 3, :o4, 1362886260
          tz.transition 2013, 11, :o3, 1383445860
          tz.transition 2014, 3, :o4, 1394335860
          tz.transition 2014, 11, :o3, 1414895460
          tz.transition 2015, 3, :o4, 1425785460
          tz.transition 2015, 11, :o3, 1446345060
          tz.transition 2016, 3, :o4, 1457839860
          tz.transition 2016, 11, :o3, 1478399460
          tz.transition 2017, 3, :o4, 1489289460
          tz.transition 2017, 11, :o3, 1509849060
          tz.transition 2018, 3, :o4, 1520739060
          tz.transition 2018, 11, :o3, 1541298660
          tz.transition 2019, 3, :o4, 1552188660
          tz.transition 2019, 11, :o3, 1572748260
          tz.transition 2020, 3, :o4, 1583638260
          tz.transition 2020, 11, :o3, 1604197860
          tz.transition 2021, 3, :o4, 1615692660
          tz.transition 2021, 11, :o3, 1636252260
          tz.transition 2022, 3, :o4, 1647142260
          tz.transition 2022, 11, :o3, 1667701860
          tz.transition 2023, 3, :o4, 1678591860
          tz.transition 2023, 11, :o3, 1699151460
          tz.transition 2024, 3, :o4, 1710041460
          tz.transition 2024, 11, :o3, 1730601060
          tz.transition 2025, 3, :o4, 1741491060
          tz.transition 2025, 11, :o3, 1762050660
          tz.transition 2026, 3, :o4, 1772940660
          tz.transition 2026, 11, :o3, 1793500260
          tz.transition 2027, 3, :o4, 1804995060
          tz.transition 2027, 11, :o3, 1825554660
          tz.transition 2028, 3, :o4, 1836444660
          tz.transition 2028, 11, :o3, 1857004260
          tz.transition 2029, 3, :o4, 1867894260
          tz.transition 2029, 11, :o3, 1888453860
          tz.transition 2030, 3, :o4, 1899343860
          tz.transition 2030, 11, :o3, 1919903460
          tz.transition 2031, 3, :o4, 1930793460
          tz.transition 2031, 11, :o3, 1951353060
          tz.transition 2032, 3, :o4, 1962847860
          tz.transition 2032, 11, :o3, 1983407460
          tz.transition 2033, 3, :o4, 1994297460
          tz.transition 2033, 11, :o3, 2014857060
          tz.transition 2034, 3, :o4, 2025747060
          tz.transition 2034, 11, :o3, 2046306660
          tz.transition 2035, 3, :o4, 2057196660
          tz.transition 2035, 11, :o3, 2077756260
          tz.transition 2036, 3, :o4, 2088646260
          tz.transition 2036, 11, :o3, 2109205860
          tz.transition 2037, 3, :o4, 2120095860
          tz.transition 2037, 11, :o3, 2140655460
          tz.transition 2038, 3, :o4, 3550315171, 1440
          tz.transition 2038, 11, :o3, 3550657831, 1440
          tz.transition 2039, 3, :o4, 3550839331, 1440
          tz.transition 2039, 11, :o3, 3551181991, 1440
          tz.transition 2040, 3, :o4, 3551363491, 1440
          tz.transition 2040, 11, :o3, 3551706151, 1440
          tz.transition 2041, 3, :o4, 3551887651, 1440
          tz.transition 2041, 11, :o3, 3552230311, 1440
          tz.transition 2042, 3, :o4, 3552411811, 1440
          tz.transition 2042, 11, :o3, 3552754471, 1440
          tz.transition 2043, 3, :o4, 3552935971, 1440
          tz.transition 2043, 11, :o3, 3553278631, 1440
          tz.transition 2044, 3, :o4, 3553470211, 1440
          tz.transition 2044, 11, :o3, 3553812871, 1440
          tz.transition 2045, 3, :o4, 3553994371, 1440
          tz.transition 2045, 11, :o3, 3554337031, 1440
          tz.transition 2046, 3, :o4, 3554518531, 1440
          tz.transition 2046, 11, :o3, 3554861191, 1440
          tz.transition 2047, 3, :o4, 3555042691, 1440
          tz.transition 2047, 11, :o3, 3555385351, 1440
          tz.transition 2048, 3, :o4, 3555566851, 1440
          tz.transition 2048, 11, :o3, 3555909511, 1440
          tz.transition 2049, 3, :o4, 3556101091, 1440
          tz.transition 2049, 11, :o3, 3556443751, 1440
          tz.transition 2050, 3, :o4, 3556625251, 1440
          tz.transition 2050, 11, :o3, 3556967911, 1440
        end
      end
    end
  end
end
