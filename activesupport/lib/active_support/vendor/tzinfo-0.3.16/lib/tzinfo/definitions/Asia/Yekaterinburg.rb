require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Yekaterinburg
        include TimezoneDefinition
        
        timezone 'Asia/Yekaterinburg' do |tz|
          tz.offset :o0, 14544, 0, :LMT
          tz.offset :o1, 14400, 0, :SVET
          tz.offset :o2, 18000, 0, :SVET
          tz.offset :o3, 18000, 3600, :SVEST
          tz.offset :o4, 14400, 3600, :SVEST
          tz.offset :o5, 18000, 0, :YEKT
          tz.offset :o6, 18000, 3600, :YEKST
          
          tz.transition 1919, 7, :o1, 1453292699, 600
          tz.transition 1930, 6, :o2, 7278445, 3
          tz.transition 1981, 3, :o3, 354913200
          tz.transition 1981, 9, :o2, 370720800
          tz.transition 1982, 3, :o3, 386449200
          tz.transition 1982, 9, :o2, 402256800
          tz.transition 1983, 3, :o3, 417985200
          tz.transition 1983, 9, :o2, 433792800
          tz.transition 1984, 3, :o3, 449607600
          tz.transition 1984, 9, :o2, 465339600
          tz.transition 1985, 3, :o3, 481064400
          tz.transition 1985, 9, :o2, 496789200
          tz.transition 1986, 3, :o3, 512514000
          tz.transition 1986, 9, :o2, 528238800
          tz.transition 1987, 3, :o3, 543963600
          tz.transition 1987, 9, :o2, 559688400
          tz.transition 1988, 3, :o3, 575413200
          tz.transition 1988, 9, :o2, 591138000
          tz.transition 1989, 3, :o3, 606862800
          tz.transition 1989, 9, :o2, 622587600
          tz.transition 1990, 3, :o3, 638312400
          tz.transition 1990, 9, :o2, 654642000
          tz.transition 1991, 3, :o4, 670366800
          tz.transition 1991, 9, :o1, 686095200
          tz.transition 1992, 1, :o5, 695772000
          tz.transition 1992, 3, :o6, 701805600
          tz.transition 1992, 9, :o5, 717526800
          tz.transition 1993, 3, :o6, 733266000
          tz.transition 1993, 9, :o5, 748990800
          tz.transition 1994, 3, :o6, 764715600
          tz.transition 1994, 9, :o5, 780440400
          tz.transition 1995, 3, :o6, 796165200
          tz.transition 1995, 9, :o5, 811890000
          tz.transition 1996, 3, :o6, 828219600
          tz.transition 1996, 10, :o5, 846363600
          tz.transition 1997, 3, :o6, 859669200
          tz.transition 1997, 10, :o5, 877813200
          tz.transition 1998, 3, :o6, 891118800
          tz.transition 1998, 10, :o5, 909262800
          tz.transition 1999, 3, :o6, 922568400
          tz.transition 1999, 10, :o5, 941317200
          tz.transition 2000, 3, :o6, 954018000
          tz.transition 2000, 10, :o5, 972766800
          tz.transition 2001, 3, :o6, 985467600
          tz.transition 2001, 10, :o5, 1004216400
          tz.transition 2002, 3, :o6, 1017522000
          tz.transition 2002, 10, :o5, 1035666000
          tz.transition 2003, 3, :o6, 1048971600
          tz.transition 2003, 10, :o5, 1067115600
          tz.transition 2004, 3, :o6, 1080421200
          tz.transition 2004, 10, :o5, 1099170000
          tz.transition 2005, 3, :o6, 1111870800
          tz.transition 2005, 10, :o5, 1130619600
          tz.transition 2006, 3, :o6, 1143320400
          tz.transition 2006, 10, :o5, 1162069200
          tz.transition 2007, 3, :o6, 1174770000
          tz.transition 2007, 10, :o5, 1193518800
          tz.transition 2008, 3, :o6, 1206824400
          tz.transition 2008, 10, :o5, 1224968400
          tz.transition 2009, 3, :o6, 1238274000
          tz.transition 2009, 10, :o5, 1256418000
          tz.transition 2010, 3, :o6, 1269723600
          tz.transition 2010, 10, :o5, 1288472400
          tz.transition 2011, 3, :o6, 1301173200
          tz.transition 2011, 10, :o5, 1319922000
          tz.transition 2012, 3, :o6, 1332622800
          tz.transition 2012, 10, :o5, 1351371600
          tz.transition 2013, 3, :o6, 1364677200
          tz.transition 2013, 10, :o5, 1382821200
          tz.transition 2014, 3, :o6, 1396126800
          tz.transition 2014, 10, :o5, 1414270800
          tz.transition 2015, 3, :o6, 1427576400
          tz.transition 2015, 10, :o5, 1445720400
          tz.transition 2016, 3, :o6, 1459026000
          tz.transition 2016, 10, :o5, 1477774800
          tz.transition 2017, 3, :o6, 1490475600
          tz.transition 2017, 10, :o5, 1509224400
          tz.transition 2018, 3, :o6, 1521925200
          tz.transition 2018, 10, :o5, 1540674000
          tz.transition 2019, 3, :o6, 1553979600
          tz.transition 2019, 10, :o5, 1572123600
          tz.transition 2020, 3, :o6, 1585429200
          tz.transition 2020, 10, :o5, 1603573200
          tz.transition 2021, 3, :o6, 1616878800
          tz.transition 2021, 10, :o5, 1635627600
          tz.transition 2022, 3, :o6, 1648328400
          tz.transition 2022, 10, :o5, 1667077200
          tz.transition 2023, 3, :o6, 1679778000
          tz.transition 2023, 10, :o5, 1698526800
          tz.transition 2024, 3, :o6, 1711832400
          tz.transition 2024, 10, :o5, 1729976400
          tz.transition 2025, 3, :o6, 1743282000
          tz.transition 2025, 10, :o5, 1761426000
          tz.transition 2026, 3, :o6, 1774731600
          tz.transition 2026, 10, :o5, 1792875600
          tz.transition 2027, 3, :o6, 1806181200
          tz.transition 2027, 10, :o5, 1824930000
          tz.transition 2028, 3, :o6, 1837630800
          tz.transition 2028, 10, :o5, 1856379600
          tz.transition 2029, 3, :o6, 1869080400
          tz.transition 2029, 10, :o5, 1887829200
          tz.transition 2030, 3, :o6, 1901134800
          tz.transition 2030, 10, :o5, 1919278800
          tz.transition 2031, 3, :o6, 1932584400
          tz.transition 2031, 10, :o5, 1950728400
          tz.transition 2032, 3, :o6, 1964034000
          tz.transition 2032, 10, :o5, 1982782800
          tz.transition 2033, 3, :o6, 1995483600
          tz.transition 2033, 10, :o5, 2014232400
          tz.transition 2034, 3, :o6, 2026933200
          tz.transition 2034, 10, :o5, 2045682000
          tz.transition 2035, 3, :o6, 2058382800
          tz.transition 2035, 10, :o5, 2077131600
          tz.transition 2036, 3, :o6, 2090437200
          tz.transition 2036, 10, :o5, 2108581200
          tz.transition 2037, 3, :o6, 2121886800
          tz.transition 2037, 10, :o5, 2140030800
          tz.transition 2038, 3, :o6, 19724083, 8
          tz.transition 2038, 10, :o5, 19725819, 8
          tz.transition 2039, 3, :o6, 19726995, 8
          tz.transition 2039, 10, :o5, 19728731, 8
          tz.transition 2040, 3, :o6, 19729907, 8
          tz.transition 2040, 10, :o5, 19731643, 8
          tz.transition 2041, 3, :o6, 19732875, 8
          tz.transition 2041, 10, :o5, 19734555, 8
          tz.transition 2042, 3, :o6, 19735787, 8
          tz.transition 2042, 10, :o5, 19737467, 8
          tz.transition 2043, 3, :o6, 19738699, 8
          tz.transition 2043, 10, :o5, 19740379, 8
          tz.transition 2044, 3, :o6, 19741611, 8
          tz.transition 2044, 10, :o5, 19743347, 8
          tz.transition 2045, 3, :o6, 19744523, 8
          tz.transition 2045, 10, :o5, 19746259, 8
          tz.transition 2046, 3, :o6, 19747435, 8
          tz.transition 2046, 10, :o5, 19749171, 8
          tz.transition 2047, 3, :o6, 19750403, 8
          tz.transition 2047, 10, :o5, 19752083, 8
          tz.transition 2048, 3, :o6, 19753315, 8
          tz.transition 2048, 10, :o5, 19754995, 8
          tz.transition 2049, 3, :o6, 19756227, 8
          tz.transition 2049, 10, :o5, 19757963, 8
          tz.transition 2050, 3, :o6, 19759139, 8
          tz.transition 2050, 10, :o5, 19760875, 8
        end
      end
    end
  end
end
