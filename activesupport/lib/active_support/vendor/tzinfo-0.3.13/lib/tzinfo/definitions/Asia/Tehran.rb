require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Tehran
        include TimezoneDefinition
        
        timezone 'Asia/Tehran' do |tz|
          tz.offset :o0, 12344, 0, :LMT
          tz.offset :o1, 12344, 0, :TMT
          tz.offset :o2, 12600, 0, :IRST
          tz.offset :o3, 14400, 0, :IRST
          tz.offset :o4, 14400, 3600, :IRDT
          tz.offset :o5, 12600, 3600, :IRDT
          
          tz.transition 1915, 12, :o1, 26145324257, 10800
          tz.transition 1945, 12, :o2, 26263670657, 10800
          tz.transition 1977, 10, :o3, 247177800
          tz.transition 1978, 3, :o4, 259272000
          tz.transition 1978, 10, :o3, 277758000
          tz.transition 1978, 12, :o2, 283982400
          tz.transition 1979, 3, :o5, 290809800
          tz.transition 1979, 9, :o2, 306531000
          tz.transition 1980, 3, :o5, 322432200
          tz.transition 1980, 9, :o2, 338499000
          tz.transition 1991, 5, :o5, 673216200
          tz.transition 1991, 9, :o2, 685481400
          tz.transition 1992, 3, :o5, 701209800
          tz.transition 1992, 9, :o2, 717103800
          tz.transition 1993, 3, :o5, 732745800
          tz.transition 1993, 9, :o2, 748639800
          tz.transition 1994, 3, :o5, 764281800
          tz.transition 1994, 9, :o2, 780175800
          tz.transition 1995, 3, :o5, 795817800
          tz.transition 1995, 9, :o2, 811711800
          tz.transition 1996, 3, :o5, 827353800
          tz.transition 1996, 9, :o2, 843247800
          tz.transition 1997, 3, :o5, 858976200
          tz.transition 1997, 9, :o2, 874870200
          tz.transition 1998, 3, :o5, 890512200
          tz.transition 1998, 9, :o2, 906406200
          tz.transition 1999, 3, :o5, 922048200
          tz.transition 1999, 9, :o2, 937942200
          tz.transition 2000, 3, :o5, 953584200
          tz.transition 2000, 9, :o2, 969478200
          tz.transition 2001, 3, :o5, 985206600
          tz.transition 2001, 9, :o2, 1001100600
          tz.transition 2002, 3, :o5, 1016742600
          tz.transition 2002, 9, :o2, 1032636600
          tz.transition 2003, 3, :o5, 1048278600
          tz.transition 2003, 9, :o2, 1064172600
          tz.transition 2004, 3, :o5, 1079814600
          tz.transition 2004, 9, :o2, 1095708600
          tz.transition 2005, 3, :o5, 1111437000
          tz.transition 2005, 9, :o2, 1127331000
          tz.transition 2008, 3, :o5, 1206045000
          tz.transition 2008, 9, :o2, 1221939000
          tz.transition 2009, 3, :o5, 1237667400
          tz.transition 2009, 9, :o2, 1253561400
          tz.transition 2010, 3, :o5, 1269203400
          tz.transition 2010, 9, :o2, 1285097400
          tz.transition 2011, 3, :o5, 1300739400
          tz.transition 2011, 9, :o2, 1316633400
          tz.transition 2012, 3, :o5, 1332275400
          tz.transition 2012, 9, :o2, 1348169400
          tz.transition 2013, 3, :o5, 1363897800
          tz.transition 2013, 9, :o2, 1379791800
          tz.transition 2014, 3, :o5, 1395433800
          tz.transition 2014, 9, :o2, 1411327800
          tz.transition 2015, 3, :o5, 1426969800
          tz.transition 2015, 9, :o2, 1442863800
          tz.transition 2016, 3, :o5, 1458505800
          tz.transition 2016, 9, :o2, 1474399800
          tz.transition 2017, 3, :o5, 1490128200
          tz.transition 2017, 9, :o2, 1506022200
          tz.transition 2018, 3, :o5, 1521664200
          tz.transition 2018, 9, :o2, 1537558200
          tz.transition 2019, 3, :o5, 1553200200
          tz.transition 2019, 9, :o2, 1569094200
          tz.transition 2020, 3, :o5, 1584736200
          tz.transition 2020, 9, :o2, 1600630200
          tz.transition 2021, 3, :o5, 1616358600
          tz.transition 2021, 9, :o2, 1632252600
          tz.transition 2022, 3, :o5, 1647894600
          tz.transition 2022, 9, :o2, 1663788600
          tz.transition 2023, 3, :o5, 1679430600
          tz.transition 2023, 9, :o2, 1695324600
          tz.transition 2024, 3, :o5, 1710966600
          tz.transition 2024, 9, :o2, 1726860600
          tz.transition 2025, 3, :o5, 1742589000
          tz.transition 2025, 9, :o2, 1758483000
          tz.transition 2026, 3, :o5, 1774125000
          tz.transition 2026, 9, :o2, 1790019000
          tz.transition 2027, 3, :o5, 1805661000
          tz.transition 2027, 9, :o2, 1821555000
          tz.transition 2028, 3, :o5, 1837197000
          tz.transition 2028, 9, :o2, 1853091000
          tz.transition 2029, 3, :o5, 1868733000
          tz.transition 2029, 9, :o2, 1884627000
          tz.transition 2030, 3, :o5, 1900355400
          tz.transition 2030, 9, :o2, 1916249400
          tz.transition 2031, 3, :o5, 1931891400
          tz.transition 2031, 9, :o2, 1947785400
          tz.transition 2032, 3, :o5, 1963427400
          tz.transition 2032, 9, :o2, 1979321400
          tz.transition 2033, 3, :o5, 1994963400
          tz.transition 2033, 9, :o2, 2010857400
          tz.transition 2034, 3, :o5, 2026585800
          tz.transition 2034, 9, :o2, 2042479800
          tz.transition 2035, 3, :o5, 2058121800
          tz.transition 2035, 9, :o2, 2074015800
          tz.transition 2036, 3, :o5, 2089657800
          tz.transition 2036, 9, :o2, 2105551800
          tz.transition 2037, 3, :o5, 2121193800
          tz.transition 2037, 9, :o2, 2137087800
        end
      end
    end
  end
end
