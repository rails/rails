require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module America
      module Mexico_City
        include TimezoneDefinition
        
        timezone 'America/Mexico_City' do |tz|
          tz.offset :o0, -23796, 0, :LMT
          tz.offset :o1, -25200, 0, :MST
          tz.offset :o2, -21600, 0, :CST
          tz.offset :o3, -21600, 3600, :CDT
          tz.offset :o4, -21600, 3600, :CWT
          
          tz.transition 1922, 1, :o1, 58153339, 24
          tz.transition 1927, 6, :o2, 9700171, 4
          tz.transition 1930, 11, :o1, 9705183, 4
          tz.transition 1931, 5, :o2, 9705855, 4
          tz.transition 1931, 10, :o1, 9706463, 4
          tz.transition 1932, 4, :o2, 58243171, 24
          tz.transition 1939, 2, :o3, 9717199, 4
          tz.transition 1939, 6, :o2, 58306553, 24
          tz.transition 1940, 12, :o3, 9719891, 4
          tz.transition 1941, 4, :o2, 58322057, 24
          tz.transition 1943, 12, :o4, 9724299, 4
          tz.transition 1944, 5, :o2, 58349081, 24
          tz.transition 1950, 2, :o3, 9733299, 4
          tz.transition 1950, 7, :o2, 58403825, 24
          tz.transition 1996, 4, :o3, 828864000
          tz.transition 1996, 10, :o2, 846399600
          tz.transition 1997, 4, :o3, 860313600
          tz.transition 1997, 10, :o2, 877849200
          tz.transition 1998, 4, :o3, 891763200
          tz.transition 1998, 10, :o2, 909298800
          tz.transition 1999, 4, :o3, 923212800
          tz.transition 1999, 10, :o2, 941353200
          tz.transition 2000, 4, :o3, 954662400
          tz.transition 2000, 10, :o2, 972802800
          tz.transition 2001, 5, :o3, 989136000
          tz.transition 2001, 9, :o2, 1001833200
          tz.transition 2002, 4, :o3, 1018166400
          tz.transition 2002, 10, :o2, 1035702000
          tz.transition 2003, 4, :o3, 1049616000
          tz.transition 2003, 10, :o2, 1067151600
          tz.transition 2004, 4, :o3, 1081065600
          tz.transition 2004, 10, :o2, 1099206000
          tz.transition 2005, 4, :o3, 1112515200
          tz.transition 2005, 10, :o2, 1130655600
          tz.transition 2006, 4, :o3, 1143964800
          tz.transition 2006, 10, :o2, 1162105200
          tz.transition 2007, 4, :o3, 1175414400
          tz.transition 2007, 10, :o2, 1193554800
          tz.transition 2008, 4, :o3, 1207468800
          tz.transition 2008, 10, :o2, 1225004400
          tz.transition 2009, 4, :o3, 1238918400
          tz.transition 2009, 10, :o2, 1256454000
          tz.transition 2010, 4, :o3, 1270368000
          tz.transition 2010, 10, :o2, 1288508400
          tz.transition 2011, 4, :o3, 1301817600
          tz.transition 2011, 10, :o2, 1319958000
          tz.transition 2012, 4, :o3, 1333267200
          tz.transition 2012, 10, :o2, 1351407600
          tz.transition 2013, 4, :o3, 1365321600
          tz.transition 2013, 10, :o2, 1382857200
          tz.transition 2014, 4, :o3, 1396771200
          tz.transition 2014, 10, :o2, 1414306800
          tz.transition 2015, 4, :o3, 1428220800
          tz.transition 2015, 10, :o2, 1445756400
          tz.transition 2016, 4, :o3, 1459670400
          tz.transition 2016, 10, :o2, 1477810800
          tz.transition 2017, 4, :o3, 1491120000
          tz.transition 2017, 10, :o2, 1509260400
          tz.transition 2018, 4, :o3, 1522569600
          tz.transition 2018, 10, :o2, 1540710000
          tz.transition 2019, 4, :o3, 1554624000
          tz.transition 2019, 10, :o2, 1572159600
          tz.transition 2020, 4, :o3, 1586073600
          tz.transition 2020, 10, :o2, 1603609200
          tz.transition 2021, 4, :o3, 1617523200
          tz.transition 2021, 10, :o2, 1635663600
          tz.transition 2022, 4, :o3, 1648972800
          tz.transition 2022, 10, :o2, 1667113200
          tz.transition 2023, 4, :o3, 1680422400
          tz.transition 2023, 10, :o2, 1698562800
          tz.transition 2024, 4, :o3, 1712476800
          tz.transition 2024, 10, :o2, 1730012400
          tz.transition 2025, 4, :o3, 1743926400
          tz.transition 2025, 10, :o2, 1761462000
          tz.transition 2026, 4, :o3, 1775376000
          tz.transition 2026, 10, :o2, 1792911600
          tz.transition 2027, 4, :o3, 1806825600
          tz.transition 2027, 10, :o2, 1824966000
          tz.transition 2028, 4, :o3, 1838275200
          tz.transition 2028, 10, :o2, 1856415600
          tz.transition 2029, 4, :o3, 1869724800
          tz.transition 2029, 10, :o2, 1887865200
          tz.transition 2030, 4, :o3, 1901779200
          tz.transition 2030, 10, :o2, 1919314800
          tz.transition 2031, 4, :o3, 1933228800
          tz.transition 2031, 10, :o2, 1950764400
          tz.transition 2032, 4, :o3, 1964678400
          tz.transition 2032, 10, :o2, 1982818800
          tz.transition 2033, 4, :o3, 1996128000
          tz.transition 2033, 10, :o2, 2014268400
          tz.transition 2034, 4, :o3, 2027577600
          tz.transition 2034, 10, :o2, 2045718000
          tz.transition 2035, 4, :o3, 2059027200
          tz.transition 2035, 10, :o2, 2077167600
          tz.transition 2036, 4, :o3, 2091081600
          tz.transition 2036, 10, :o2, 2108617200
          tz.transition 2037, 4, :o3, 2122531200
          tz.transition 2037, 10, :o2, 2140066800
          tz.transition 2038, 4, :o3, 14793107, 6
          tz.transition 2038, 10, :o2, 59177467, 24
          tz.transition 2039, 4, :o3, 14795291, 6
          tz.transition 2039, 10, :o2, 59186203, 24
          tz.transition 2040, 4, :o3, 14797475, 6
          tz.transition 2040, 10, :o2, 59194939, 24
          tz.transition 2041, 4, :o3, 14799701, 6
          tz.transition 2041, 10, :o2, 59203675, 24
          tz.transition 2042, 4, :o3, 14801885, 6
          tz.transition 2042, 10, :o2, 59212411, 24
          tz.transition 2043, 4, :o3, 14804069, 6
          tz.transition 2043, 10, :o2, 59221147, 24
          tz.transition 2044, 4, :o3, 14806253, 6
          tz.transition 2044, 10, :o2, 59230051, 24
          tz.transition 2045, 4, :o3, 14808437, 6
          tz.transition 2045, 10, :o2, 59238787, 24
          tz.transition 2046, 4, :o3, 14810621, 6
          tz.transition 2046, 10, :o2, 59247523, 24
          tz.transition 2047, 4, :o3, 14812847, 6
          tz.transition 2047, 10, :o2, 59256259, 24
          tz.transition 2048, 4, :o3, 14815031, 6
          tz.transition 2048, 10, :o2, 59264995, 24
          tz.transition 2049, 4, :o3, 14817215, 6
          tz.transition 2049, 10, :o2, 59273899, 24
          tz.transition 2050, 4, :o3, 14819399, 6
          tz.transition 2050, 10, :o2, 59282635, 24
        end
      end
    end
  end
end
