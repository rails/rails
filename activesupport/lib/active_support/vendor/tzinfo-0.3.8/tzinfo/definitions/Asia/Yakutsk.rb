require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Yakutsk
        include TimezoneDefinition
        
        timezone 'Asia/Yakutsk' do |tz|
          tz.offset :o0, 31120, 0, :LMT
          tz.offset :o1, 28800, 0, :YAKT
          tz.offset :o2, 32400, 0, :YAKT
          tz.offset :o3, 32400, 3600, :YAKST
          tz.offset :o4, 28800, 3600, :YAKST
          
          tz.transition 1919, 12, :o1, 2616091711, 1080
          tz.transition 1930, 6, :o2, 14556889, 6
          tz.transition 1981, 3, :o3, 354898800
          tz.transition 1981, 9, :o2, 370706400
          tz.transition 1982, 3, :o3, 386434800
          tz.transition 1982, 9, :o2, 402242400
          tz.transition 1983, 3, :o3, 417970800
          tz.transition 1983, 9, :o2, 433778400
          tz.transition 1984, 3, :o3, 449593200
          tz.transition 1984, 9, :o2, 465325200
          tz.transition 1985, 3, :o3, 481050000
          tz.transition 1985, 9, :o2, 496774800
          tz.transition 1986, 3, :o3, 512499600
          tz.transition 1986, 9, :o2, 528224400
          tz.transition 1987, 3, :o3, 543949200
          tz.transition 1987, 9, :o2, 559674000
          tz.transition 1988, 3, :o3, 575398800
          tz.transition 1988, 9, :o2, 591123600
          tz.transition 1989, 3, :o3, 606848400
          tz.transition 1989, 9, :o2, 622573200
          tz.transition 1990, 3, :o3, 638298000
          tz.transition 1990, 9, :o2, 654627600
          tz.transition 1991, 3, :o4, 670352400
          tz.transition 1991, 9, :o1, 686080800
          tz.transition 1992, 1, :o2, 695757600
          tz.transition 1992, 3, :o3, 701791200
          tz.transition 1992, 9, :o2, 717512400
          tz.transition 1993, 3, :o3, 733251600
          tz.transition 1993, 9, :o2, 748976400
          tz.transition 1994, 3, :o3, 764701200
          tz.transition 1994, 9, :o2, 780426000
          tz.transition 1995, 3, :o3, 796150800
          tz.transition 1995, 9, :o2, 811875600
          tz.transition 1996, 3, :o3, 828205200
          tz.transition 1996, 10, :o2, 846349200
          tz.transition 1997, 3, :o3, 859654800
          tz.transition 1997, 10, :o2, 877798800
          tz.transition 1998, 3, :o3, 891104400
          tz.transition 1998, 10, :o2, 909248400
          tz.transition 1999, 3, :o3, 922554000
          tz.transition 1999, 10, :o2, 941302800
          tz.transition 2000, 3, :o3, 954003600
          tz.transition 2000, 10, :o2, 972752400
          tz.transition 2001, 3, :o3, 985453200
          tz.transition 2001, 10, :o2, 1004202000
          tz.transition 2002, 3, :o3, 1017507600
          tz.transition 2002, 10, :o2, 1035651600
          tz.transition 2003, 3, :o3, 1048957200
          tz.transition 2003, 10, :o2, 1067101200
          tz.transition 2004, 3, :o3, 1080406800
          tz.transition 2004, 10, :o2, 1099155600
          tz.transition 2005, 3, :o3, 1111856400
          tz.transition 2005, 10, :o2, 1130605200
          tz.transition 2006, 3, :o3, 1143306000
          tz.transition 2006, 10, :o2, 1162054800
          tz.transition 2007, 3, :o3, 1174755600
          tz.transition 2007, 10, :o2, 1193504400
          tz.transition 2008, 3, :o3, 1206810000
          tz.transition 2008, 10, :o2, 1224954000
          tz.transition 2009, 3, :o3, 1238259600
          tz.transition 2009, 10, :o2, 1256403600
          tz.transition 2010, 3, :o3, 1269709200
          tz.transition 2010, 10, :o2, 1288458000
          tz.transition 2011, 3, :o3, 1301158800
          tz.transition 2011, 10, :o2, 1319907600
          tz.transition 2012, 3, :o3, 1332608400
          tz.transition 2012, 10, :o2, 1351357200
          tz.transition 2013, 3, :o3, 1364662800
          tz.transition 2013, 10, :o2, 1382806800
          tz.transition 2014, 3, :o3, 1396112400
          tz.transition 2014, 10, :o2, 1414256400
          tz.transition 2015, 3, :o3, 1427562000
          tz.transition 2015, 10, :o2, 1445706000
          tz.transition 2016, 3, :o3, 1459011600
          tz.transition 2016, 10, :o2, 1477760400
          tz.transition 2017, 3, :o3, 1490461200
          tz.transition 2017, 10, :o2, 1509210000
          tz.transition 2018, 3, :o3, 1521910800
          tz.transition 2018, 10, :o2, 1540659600
          tz.transition 2019, 3, :o3, 1553965200
          tz.transition 2019, 10, :o2, 1572109200
          tz.transition 2020, 3, :o3, 1585414800
          tz.transition 2020, 10, :o2, 1603558800
          tz.transition 2021, 3, :o3, 1616864400
          tz.transition 2021, 10, :o2, 1635613200
          tz.transition 2022, 3, :o3, 1648314000
          tz.transition 2022, 10, :o2, 1667062800
          tz.transition 2023, 3, :o3, 1679763600
          tz.transition 2023, 10, :o2, 1698512400
          tz.transition 2024, 3, :o3, 1711818000
          tz.transition 2024, 10, :o2, 1729962000
          tz.transition 2025, 3, :o3, 1743267600
          tz.transition 2025, 10, :o2, 1761411600
          tz.transition 2026, 3, :o3, 1774717200
          tz.transition 2026, 10, :o2, 1792861200
          tz.transition 2027, 3, :o3, 1806166800
          tz.transition 2027, 10, :o2, 1824915600
          tz.transition 2028, 3, :o3, 1837616400
          tz.transition 2028, 10, :o2, 1856365200
          tz.transition 2029, 3, :o3, 1869066000
          tz.transition 2029, 10, :o2, 1887814800
          tz.transition 2030, 3, :o3, 1901120400
          tz.transition 2030, 10, :o2, 1919264400
          tz.transition 2031, 3, :o3, 1932570000
          tz.transition 2031, 10, :o2, 1950714000
          tz.transition 2032, 3, :o3, 1964019600
          tz.transition 2032, 10, :o2, 1982768400
          tz.transition 2033, 3, :o3, 1995469200
          tz.transition 2033, 10, :o2, 2014218000
          tz.transition 2034, 3, :o3, 2026918800
          tz.transition 2034, 10, :o2, 2045667600
          tz.transition 2035, 3, :o3, 2058368400
          tz.transition 2035, 10, :o2, 2077117200
          tz.transition 2036, 3, :o3, 2090422800
          tz.transition 2036, 10, :o2, 2108566800
          tz.transition 2037, 3, :o3, 2121872400
          tz.transition 2037, 10, :o2, 2140016400
          tz.transition 2038, 3, :o3, 59172245, 24
          tz.transition 2038, 10, :o2, 59177453, 24
          tz.transition 2039, 3, :o3, 59180981, 24
          tz.transition 2039, 10, :o2, 59186189, 24
          tz.transition 2040, 3, :o3, 59189717, 24
          tz.transition 2040, 10, :o2, 59194925, 24
          tz.transition 2041, 3, :o3, 59198621, 24
          tz.transition 2041, 10, :o2, 59203661, 24
          tz.transition 2042, 3, :o3, 59207357, 24
          tz.transition 2042, 10, :o2, 59212397, 24
          tz.transition 2043, 3, :o3, 59216093, 24
          tz.transition 2043, 10, :o2, 59221133, 24
          tz.transition 2044, 3, :o3, 59224829, 24
          tz.transition 2044, 10, :o2, 59230037, 24
          tz.transition 2045, 3, :o3, 59233565, 24
          tz.transition 2045, 10, :o2, 59238773, 24
          tz.transition 2046, 3, :o3, 59242301, 24
          tz.transition 2046, 10, :o2, 59247509, 24
          tz.transition 2047, 3, :o3, 59251205, 24
          tz.transition 2047, 10, :o2, 59256245, 24
          tz.transition 2048, 3, :o3, 59259941, 24
          tz.transition 2048, 10, :o2, 59264981, 24
          tz.transition 2049, 3, :o3, 59268677, 24
          tz.transition 2049, 10, :o2, 59273885, 24
          tz.transition 2050, 3, :o3, 59277413, 24
          tz.transition 2050, 10, :o2, 59282621, 24
        end
      end
    end
  end
end
