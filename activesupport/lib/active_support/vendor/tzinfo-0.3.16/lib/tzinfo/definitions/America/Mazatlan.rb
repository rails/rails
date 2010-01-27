require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module America
      module Mazatlan
        include TimezoneDefinition
        
        timezone 'America/Mazatlan' do |tz|
          tz.offset :o0, -25540, 0, :LMT
          tz.offset :o1, -25200, 0, :MST
          tz.offset :o2, -21600, 0, :CST
          tz.offset :o3, -28800, 0, :PST
          tz.offset :o4, -25200, 3600, :MDT
          
          tz.transition 1922, 1, :o1, 58153339, 24
          tz.transition 1927, 6, :o2, 9700171, 4
          tz.transition 1930, 11, :o1, 9705183, 4
          tz.transition 1931, 5, :o2, 9705855, 4
          tz.transition 1931, 10, :o1, 9706463, 4
          tz.transition 1932, 4, :o2, 58243171, 24
          tz.transition 1942, 4, :o1, 9721895, 4
          tz.transition 1949, 1, :o3, 58390339, 24
          tz.transition 1970, 1, :o1, 28800
          tz.transition 1996, 4, :o4, 828867600
          tz.transition 1996, 10, :o1, 846403200
          tz.transition 1997, 4, :o4, 860317200
          tz.transition 1997, 10, :o1, 877852800
          tz.transition 1998, 4, :o4, 891766800
          tz.transition 1998, 10, :o1, 909302400
          tz.transition 1999, 4, :o4, 923216400
          tz.transition 1999, 10, :o1, 941356800
          tz.transition 2000, 4, :o4, 954666000
          tz.transition 2000, 10, :o1, 972806400
          tz.transition 2001, 5, :o4, 989139600
          tz.transition 2001, 9, :o1, 1001836800
          tz.transition 2002, 4, :o4, 1018170000
          tz.transition 2002, 10, :o1, 1035705600
          tz.transition 2003, 4, :o4, 1049619600
          tz.transition 2003, 10, :o1, 1067155200
          tz.transition 2004, 4, :o4, 1081069200
          tz.transition 2004, 10, :o1, 1099209600
          tz.transition 2005, 4, :o4, 1112518800
          tz.transition 2005, 10, :o1, 1130659200
          tz.transition 2006, 4, :o4, 1143968400
          tz.transition 2006, 10, :o1, 1162108800
          tz.transition 2007, 4, :o4, 1175418000
          tz.transition 2007, 10, :o1, 1193558400
          tz.transition 2008, 4, :o4, 1207472400
          tz.transition 2008, 10, :o1, 1225008000
          tz.transition 2009, 4, :o4, 1238922000
          tz.transition 2009, 10, :o1, 1256457600
          tz.transition 2010, 4, :o4, 1270371600
          tz.transition 2010, 10, :o1, 1288512000
          tz.transition 2011, 4, :o4, 1301821200
          tz.transition 2011, 10, :o1, 1319961600
          tz.transition 2012, 4, :o4, 1333270800
          tz.transition 2012, 10, :o1, 1351411200
          tz.transition 2013, 4, :o4, 1365325200
          tz.transition 2013, 10, :o1, 1382860800
          tz.transition 2014, 4, :o4, 1396774800
          tz.transition 2014, 10, :o1, 1414310400
          tz.transition 2015, 4, :o4, 1428224400
          tz.transition 2015, 10, :o1, 1445760000
          tz.transition 2016, 4, :o4, 1459674000
          tz.transition 2016, 10, :o1, 1477814400
          tz.transition 2017, 4, :o4, 1491123600
          tz.transition 2017, 10, :o1, 1509264000
          tz.transition 2018, 4, :o4, 1522573200
          tz.transition 2018, 10, :o1, 1540713600
          tz.transition 2019, 4, :o4, 1554627600
          tz.transition 2019, 10, :o1, 1572163200
          tz.transition 2020, 4, :o4, 1586077200
          tz.transition 2020, 10, :o1, 1603612800
          tz.transition 2021, 4, :o4, 1617526800
          tz.transition 2021, 10, :o1, 1635667200
          tz.transition 2022, 4, :o4, 1648976400
          tz.transition 2022, 10, :o1, 1667116800
          tz.transition 2023, 4, :o4, 1680426000
          tz.transition 2023, 10, :o1, 1698566400
          tz.transition 2024, 4, :o4, 1712480400
          tz.transition 2024, 10, :o1, 1730016000
          tz.transition 2025, 4, :o4, 1743930000
          tz.transition 2025, 10, :o1, 1761465600
          tz.transition 2026, 4, :o4, 1775379600
          tz.transition 2026, 10, :o1, 1792915200
          tz.transition 2027, 4, :o4, 1806829200
          tz.transition 2027, 10, :o1, 1824969600
          tz.transition 2028, 4, :o4, 1838278800
          tz.transition 2028, 10, :o1, 1856419200
          tz.transition 2029, 4, :o4, 1869728400
          tz.transition 2029, 10, :o1, 1887868800
          tz.transition 2030, 4, :o4, 1901782800
          tz.transition 2030, 10, :o1, 1919318400
          tz.transition 2031, 4, :o4, 1933232400
          tz.transition 2031, 10, :o1, 1950768000
          tz.transition 2032, 4, :o4, 1964682000
          tz.transition 2032, 10, :o1, 1982822400
          tz.transition 2033, 4, :o4, 1996131600
          tz.transition 2033, 10, :o1, 2014272000
          tz.transition 2034, 4, :o4, 2027581200
          tz.transition 2034, 10, :o1, 2045721600
          tz.transition 2035, 4, :o4, 2059030800
          tz.transition 2035, 10, :o1, 2077171200
          tz.transition 2036, 4, :o4, 2091085200
          tz.transition 2036, 10, :o1, 2108620800
          tz.transition 2037, 4, :o4, 2122534800
          tz.transition 2037, 10, :o1, 2140070400
          tz.transition 2038, 4, :o4, 19724143, 8
          tz.transition 2038, 10, :o1, 14794367, 6
          tz.transition 2039, 4, :o4, 19727055, 8
          tz.transition 2039, 10, :o1, 14796551, 6
          tz.transition 2040, 4, :o4, 19729967, 8
          tz.transition 2040, 10, :o1, 14798735, 6
          tz.transition 2041, 4, :o4, 19732935, 8
          tz.transition 2041, 10, :o1, 14800919, 6
          tz.transition 2042, 4, :o4, 19735847, 8
          tz.transition 2042, 10, :o1, 14803103, 6
          tz.transition 2043, 4, :o4, 19738759, 8
          tz.transition 2043, 10, :o1, 14805287, 6
          tz.transition 2044, 4, :o4, 19741671, 8
          tz.transition 2044, 10, :o1, 14807513, 6
          tz.transition 2045, 4, :o4, 19744583, 8
          tz.transition 2045, 10, :o1, 14809697, 6
          tz.transition 2046, 4, :o4, 19747495, 8
          tz.transition 2046, 10, :o1, 14811881, 6
          tz.transition 2047, 4, :o4, 19750463, 8
          tz.transition 2047, 10, :o1, 14814065, 6
          tz.transition 2048, 4, :o4, 19753375, 8
          tz.transition 2048, 10, :o1, 14816249, 6
          tz.transition 2049, 4, :o4, 19756287, 8
          tz.transition 2049, 10, :o1, 14818475, 6
          tz.transition 2050, 4, :o4, 19759199, 8
          tz.transition 2050, 10, :o1, 14820659, 6
        end
      end
    end
  end
end
