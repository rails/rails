require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Europe
      module Minsk
        include TimezoneDefinition
        
        timezone 'Europe/Minsk' do |tz|
          tz.offset :o0, 6616, 0, :LMT
          tz.offset :o1, 6600, 0, :MMT
          tz.offset :o2, 7200, 0, :EET
          tz.offset :o3, 10800, 0, :MSK
          tz.offset :o4, 3600, 3600, :CEST
          tz.offset :o5, 3600, 0, :CET
          tz.offset :o6, 10800, 3600, :MSD
          tz.offset :o7, 7200, 3600, :EEST
          
          tz.transition 1879, 12, :o1, 26003326573, 10800
          tz.transition 1924, 5, :o2, 349042669, 144
          tz.transition 1930, 6, :o3, 29113781, 12
          tz.transition 1941, 6, :o4, 19441387, 8
          tz.transition 1942, 11, :o5, 58335973, 24
          tz.transition 1943, 3, :o4, 58339501, 24
          tz.transition 1943, 10, :o5, 58344037, 24
          tz.transition 1944, 4, :o4, 58348405, 24
          tz.transition 1944, 7, :o3, 29175293, 12
          tz.transition 1981, 3, :o6, 354920400
          tz.transition 1981, 9, :o3, 370728000
          tz.transition 1982, 3, :o6, 386456400
          tz.transition 1982, 9, :o3, 402264000
          tz.transition 1983, 3, :o6, 417992400
          tz.transition 1983, 9, :o3, 433800000
          tz.transition 1984, 3, :o6, 449614800
          tz.transition 1984, 9, :o3, 465346800
          tz.transition 1985, 3, :o6, 481071600
          tz.transition 1985, 9, :o3, 496796400
          tz.transition 1986, 3, :o6, 512521200
          tz.transition 1986, 9, :o3, 528246000
          tz.transition 1987, 3, :o6, 543970800
          tz.transition 1987, 9, :o3, 559695600
          tz.transition 1988, 3, :o6, 575420400
          tz.transition 1988, 9, :o3, 591145200
          tz.transition 1989, 3, :o6, 606870000
          tz.transition 1989, 9, :o3, 622594800
          tz.transition 1991, 3, :o7, 670374000
          tz.transition 1991, 9, :o2, 686102400
          tz.transition 1992, 3, :o7, 701820000
          tz.transition 1992, 9, :o2, 717544800
          tz.transition 1993, 3, :o7, 733276800
          tz.transition 1993, 9, :o2, 749001600
          tz.transition 1994, 3, :o7, 764726400
          tz.transition 1994, 9, :o2, 780451200
          tz.transition 1995, 3, :o7, 796176000
          tz.transition 1995, 9, :o2, 811900800
          tz.transition 1996, 3, :o7, 828230400
          tz.transition 1996, 10, :o2, 846374400
          tz.transition 1997, 3, :o7, 859680000
          tz.transition 1997, 10, :o2, 877824000
          tz.transition 1998, 3, :o7, 891129600
          tz.transition 1998, 10, :o2, 909273600
          tz.transition 1999, 3, :o7, 922579200
          tz.transition 1999, 10, :o2, 941328000
          tz.transition 2000, 3, :o7, 954028800
          tz.transition 2000, 10, :o2, 972777600
          tz.transition 2001, 3, :o7, 985478400
          tz.transition 2001, 10, :o2, 1004227200
          tz.transition 2002, 3, :o7, 1017532800
          tz.transition 2002, 10, :o2, 1035676800
          tz.transition 2003, 3, :o7, 1048982400
          tz.transition 2003, 10, :o2, 1067126400
          tz.transition 2004, 3, :o7, 1080432000
          tz.transition 2004, 10, :o2, 1099180800
          tz.transition 2005, 3, :o7, 1111881600
          tz.transition 2005, 10, :o2, 1130630400
          tz.transition 2006, 3, :o7, 1143331200
          tz.transition 2006, 10, :o2, 1162080000
          tz.transition 2007, 3, :o7, 1174780800
          tz.transition 2007, 10, :o2, 1193529600
          tz.transition 2008, 3, :o7, 1206835200
          tz.transition 2008, 10, :o2, 1224979200
          tz.transition 2009, 3, :o7, 1238284800
          tz.transition 2009, 10, :o2, 1256428800
          tz.transition 2010, 3, :o7, 1269734400
          tz.transition 2010, 10, :o2, 1288483200
          tz.transition 2011, 3, :o7, 1301184000
          tz.transition 2011, 10, :o2, 1319932800
          tz.transition 2012, 3, :o7, 1332633600
          tz.transition 2012, 10, :o2, 1351382400
          tz.transition 2013, 3, :o7, 1364688000
          tz.transition 2013, 10, :o2, 1382832000
          tz.transition 2014, 3, :o7, 1396137600
          tz.transition 2014, 10, :o2, 1414281600
          tz.transition 2015, 3, :o7, 1427587200
          tz.transition 2015, 10, :o2, 1445731200
          tz.transition 2016, 3, :o7, 1459036800
          tz.transition 2016, 10, :o2, 1477785600
          tz.transition 2017, 3, :o7, 1490486400
          tz.transition 2017, 10, :o2, 1509235200
          tz.transition 2018, 3, :o7, 1521936000
          tz.transition 2018, 10, :o2, 1540684800
          tz.transition 2019, 3, :o7, 1553990400
          tz.transition 2019, 10, :o2, 1572134400
          tz.transition 2020, 3, :o7, 1585440000
          tz.transition 2020, 10, :o2, 1603584000
          tz.transition 2021, 3, :o7, 1616889600
          tz.transition 2021, 10, :o2, 1635638400
          tz.transition 2022, 3, :o7, 1648339200
          tz.transition 2022, 10, :o2, 1667088000
          tz.transition 2023, 3, :o7, 1679788800
          tz.transition 2023, 10, :o2, 1698537600
          tz.transition 2024, 3, :o7, 1711843200
          tz.transition 2024, 10, :o2, 1729987200
          tz.transition 2025, 3, :o7, 1743292800
          tz.transition 2025, 10, :o2, 1761436800
          tz.transition 2026, 3, :o7, 1774742400
          tz.transition 2026, 10, :o2, 1792886400
          tz.transition 2027, 3, :o7, 1806192000
          tz.transition 2027, 10, :o2, 1824940800
          tz.transition 2028, 3, :o7, 1837641600
          tz.transition 2028, 10, :o2, 1856390400
          tz.transition 2029, 3, :o7, 1869091200
          tz.transition 2029, 10, :o2, 1887840000
          tz.transition 2030, 3, :o7, 1901145600
          tz.transition 2030, 10, :o2, 1919289600
          tz.transition 2031, 3, :o7, 1932595200
          tz.transition 2031, 10, :o2, 1950739200
          tz.transition 2032, 3, :o7, 1964044800
          tz.transition 2032, 10, :o2, 1982793600
          tz.transition 2033, 3, :o7, 1995494400
          tz.transition 2033, 10, :o2, 2014243200
          tz.transition 2034, 3, :o7, 2026944000
          tz.transition 2034, 10, :o2, 2045692800
          tz.transition 2035, 3, :o7, 2058393600
          tz.transition 2035, 10, :o2, 2077142400
          tz.transition 2036, 3, :o7, 2090448000
          tz.transition 2036, 10, :o2, 2108592000
          tz.transition 2037, 3, :o7, 2121897600
          tz.transition 2037, 10, :o2, 2140041600
          tz.transition 2038, 3, :o7, 4931021, 2
          tz.transition 2038, 10, :o2, 4931455, 2
          tz.transition 2039, 3, :o7, 4931749, 2
          tz.transition 2039, 10, :o2, 4932183, 2
          tz.transition 2040, 3, :o7, 4932477, 2
          tz.transition 2040, 10, :o2, 4932911, 2
          tz.transition 2041, 3, :o7, 4933219, 2
          tz.transition 2041, 10, :o2, 4933639, 2
          tz.transition 2042, 3, :o7, 4933947, 2
          tz.transition 2042, 10, :o2, 4934367, 2
          tz.transition 2043, 3, :o7, 4934675, 2
          tz.transition 2043, 10, :o2, 4935095, 2
          tz.transition 2044, 3, :o7, 4935403, 2
          tz.transition 2044, 10, :o2, 4935837, 2
          tz.transition 2045, 3, :o7, 4936131, 2
          tz.transition 2045, 10, :o2, 4936565, 2
          tz.transition 2046, 3, :o7, 4936859, 2
          tz.transition 2046, 10, :o2, 4937293, 2
          tz.transition 2047, 3, :o7, 4937601, 2
          tz.transition 2047, 10, :o2, 4938021, 2
          tz.transition 2048, 3, :o7, 4938329, 2
          tz.transition 2048, 10, :o2, 4938749, 2
          tz.transition 2049, 3, :o7, 4939057, 2
          tz.transition 2049, 10, :o2, 4939491, 2
          tz.transition 2050, 3, :o7, 4939785, 2
          tz.transition 2050, 10, :o2, 4940219, 2
        end
      end
    end
  end
end
