require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Irkutsk
        include TimezoneDefinition
        
        timezone 'Asia/Irkutsk' do |tz|
          tz.offset :o0, 25040, 0, :LMT
          tz.offset :o1, 25040, 0, :IMT
          tz.offset :o2, 25200, 0, :IRKT
          tz.offset :o3, 28800, 0, :IRKT
          tz.offset :o4, 28800, 3600, :IRKST
          tz.offset :o5, 25200, 3600, :IRKST
          
          tz.transition 1879, 12, :o1, 2600332427, 1080
          tz.transition 1920, 1, :o2, 2616136067, 1080
          tz.transition 1930, 6, :o3, 58227557, 24
          tz.transition 1981, 3, :o4, 354902400
          tz.transition 1981, 9, :o3, 370710000
          tz.transition 1982, 3, :o4, 386438400
          tz.transition 1982, 9, :o3, 402246000
          tz.transition 1983, 3, :o4, 417974400
          tz.transition 1983, 9, :o3, 433782000
          tz.transition 1984, 3, :o4, 449596800
          tz.transition 1984, 9, :o3, 465328800
          tz.transition 1985, 3, :o4, 481053600
          tz.transition 1985, 9, :o3, 496778400
          tz.transition 1986, 3, :o4, 512503200
          tz.transition 1986, 9, :o3, 528228000
          tz.transition 1987, 3, :o4, 543952800
          tz.transition 1987, 9, :o3, 559677600
          tz.transition 1988, 3, :o4, 575402400
          tz.transition 1988, 9, :o3, 591127200
          tz.transition 1989, 3, :o4, 606852000
          tz.transition 1989, 9, :o3, 622576800
          tz.transition 1990, 3, :o4, 638301600
          tz.transition 1990, 9, :o3, 654631200
          tz.transition 1991, 3, :o5, 670356000
          tz.transition 1991, 9, :o2, 686084400
          tz.transition 1992, 1, :o3, 695761200
          tz.transition 1992, 3, :o4, 701794800
          tz.transition 1992, 9, :o3, 717516000
          tz.transition 1993, 3, :o4, 733255200
          tz.transition 1993, 9, :o3, 748980000
          tz.transition 1994, 3, :o4, 764704800
          tz.transition 1994, 9, :o3, 780429600
          tz.transition 1995, 3, :o4, 796154400
          tz.transition 1995, 9, :o3, 811879200
          tz.transition 1996, 3, :o4, 828208800
          tz.transition 1996, 10, :o3, 846352800
          tz.transition 1997, 3, :o4, 859658400
          tz.transition 1997, 10, :o3, 877802400
          tz.transition 1998, 3, :o4, 891108000
          tz.transition 1998, 10, :o3, 909252000
          tz.transition 1999, 3, :o4, 922557600
          tz.transition 1999, 10, :o3, 941306400
          tz.transition 2000, 3, :o4, 954007200
          tz.transition 2000, 10, :o3, 972756000
          tz.transition 2001, 3, :o4, 985456800
          tz.transition 2001, 10, :o3, 1004205600
          tz.transition 2002, 3, :o4, 1017511200
          tz.transition 2002, 10, :o3, 1035655200
          tz.transition 2003, 3, :o4, 1048960800
          tz.transition 2003, 10, :o3, 1067104800
          tz.transition 2004, 3, :o4, 1080410400
          tz.transition 2004, 10, :o3, 1099159200
          tz.transition 2005, 3, :o4, 1111860000
          tz.transition 2005, 10, :o3, 1130608800
          tz.transition 2006, 3, :o4, 1143309600
          tz.transition 2006, 10, :o3, 1162058400
          tz.transition 2007, 3, :o4, 1174759200
          tz.transition 2007, 10, :o3, 1193508000
          tz.transition 2008, 3, :o4, 1206813600
          tz.transition 2008, 10, :o3, 1224957600
          tz.transition 2009, 3, :o4, 1238263200
          tz.transition 2009, 10, :o3, 1256407200
          tz.transition 2010, 3, :o4, 1269712800
          tz.transition 2010, 10, :o3, 1288461600
          tz.transition 2011, 3, :o4, 1301162400
          tz.transition 2011, 10, :o3, 1319911200
          tz.transition 2012, 3, :o4, 1332612000
          tz.transition 2012, 10, :o3, 1351360800
          tz.transition 2013, 3, :o4, 1364666400
          tz.transition 2013, 10, :o3, 1382810400
          tz.transition 2014, 3, :o4, 1396116000
          tz.transition 2014, 10, :o3, 1414260000
          tz.transition 2015, 3, :o4, 1427565600
          tz.transition 2015, 10, :o3, 1445709600
          tz.transition 2016, 3, :o4, 1459015200
          tz.transition 2016, 10, :o3, 1477764000
          tz.transition 2017, 3, :o4, 1490464800
          tz.transition 2017, 10, :o3, 1509213600
          tz.transition 2018, 3, :o4, 1521914400
          tz.transition 2018, 10, :o3, 1540663200
          tz.transition 2019, 3, :o4, 1553968800
          tz.transition 2019, 10, :o3, 1572112800
          tz.transition 2020, 3, :o4, 1585418400
          tz.transition 2020, 10, :o3, 1603562400
          tz.transition 2021, 3, :o4, 1616868000
          tz.transition 2021, 10, :o3, 1635616800
          tz.transition 2022, 3, :o4, 1648317600
          tz.transition 2022, 10, :o3, 1667066400
          tz.transition 2023, 3, :o4, 1679767200
          tz.transition 2023, 10, :o3, 1698516000
          tz.transition 2024, 3, :o4, 1711821600
          tz.transition 2024, 10, :o3, 1729965600
          tz.transition 2025, 3, :o4, 1743271200
          tz.transition 2025, 10, :o3, 1761415200
          tz.transition 2026, 3, :o4, 1774720800
          tz.transition 2026, 10, :o3, 1792864800
          tz.transition 2027, 3, :o4, 1806170400
          tz.transition 2027, 10, :o3, 1824919200
          tz.transition 2028, 3, :o4, 1837620000
          tz.transition 2028, 10, :o3, 1856368800
          tz.transition 2029, 3, :o4, 1869069600
          tz.transition 2029, 10, :o3, 1887818400
          tz.transition 2030, 3, :o4, 1901124000
          tz.transition 2030, 10, :o3, 1919268000
          tz.transition 2031, 3, :o4, 1932573600
          tz.transition 2031, 10, :o3, 1950717600
          tz.transition 2032, 3, :o4, 1964023200
          tz.transition 2032, 10, :o3, 1982772000
          tz.transition 2033, 3, :o4, 1995472800
          tz.transition 2033, 10, :o3, 2014221600
          tz.transition 2034, 3, :o4, 2026922400
          tz.transition 2034, 10, :o3, 2045671200
          tz.transition 2035, 3, :o4, 2058372000
          tz.transition 2035, 10, :o3, 2077120800
          tz.transition 2036, 3, :o4, 2090426400
          tz.transition 2036, 10, :o3, 2108570400
          tz.transition 2037, 3, :o4, 2121876000
          tz.transition 2037, 10, :o3, 2140020000
          tz.transition 2038, 3, :o4, 9862041, 4
          tz.transition 2038, 10, :o3, 9862909, 4
          tz.transition 2039, 3, :o4, 9863497, 4
          tz.transition 2039, 10, :o3, 9864365, 4
          tz.transition 2040, 3, :o4, 9864953, 4
          tz.transition 2040, 10, :o3, 9865821, 4
          tz.transition 2041, 3, :o4, 9866437, 4
          tz.transition 2041, 10, :o3, 9867277, 4
          tz.transition 2042, 3, :o4, 9867893, 4
          tz.transition 2042, 10, :o3, 9868733, 4
          tz.transition 2043, 3, :o4, 9869349, 4
          tz.transition 2043, 10, :o3, 9870189, 4
          tz.transition 2044, 3, :o4, 9870805, 4
          tz.transition 2044, 10, :o3, 9871673, 4
          tz.transition 2045, 3, :o4, 9872261, 4
          tz.transition 2045, 10, :o3, 9873129, 4
          tz.transition 2046, 3, :o4, 9873717, 4
          tz.transition 2046, 10, :o3, 9874585, 4
          tz.transition 2047, 3, :o4, 9875201, 4
          tz.transition 2047, 10, :o3, 9876041, 4
          tz.transition 2048, 3, :o4, 9876657, 4
          tz.transition 2048, 10, :o3, 9877497, 4
          tz.transition 2049, 3, :o4, 9878113, 4
          tz.transition 2049, 10, :o3, 9878981, 4
          tz.transition 2050, 3, :o4, 9879569, 4
          tz.transition 2050, 10, :o3, 9880437, 4
        end
      end
    end
  end
end
