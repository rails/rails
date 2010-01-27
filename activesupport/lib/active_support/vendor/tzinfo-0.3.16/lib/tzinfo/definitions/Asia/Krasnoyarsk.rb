require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Krasnoyarsk
        include TimezoneDefinition
        
        timezone 'Asia/Krasnoyarsk' do |tz|
          tz.offset :o0, 22280, 0, :LMT
          tz.offset :o1, 21600, 0, :KRAT
          tz.offset :o2, 25200, 0, :KRAT
          tz.offset :o3, 25200, 3600, :KRAST
          tz.offset :o4, 21600, 3600, :KRAST
          
          tz.transition 1920, 1, :o1, 5232231163, 2160
          tz.transition 1930, 6, :o2, 9704593, 4
          tz.transition 1981, 3, :o3, 354906000
          tz.transition 1981, 9, :o2, 370713600
          tz.transition 1982, 3, :o3, 386442000
          tz.transition 1982, 9, :o2, 402249600
          tz.transition 1983, 3, :o3, 417978000
          tz.transition 1983, 9, :o2, 433785600
          tz.transition 1984, 3, :o3, 449600400
          tz.transition 1984, 9, :o2, 465332400
          tz.transition 1985, 3, :o3, 481057200
          tz.transition 1985, 9, :o2, 496782000
          tz.transition 1986, 3, :o3, 512506800
          tz.transition 1986, 9, :o2, 528231600
          tz.transition 1987, 3, :o3, 543956400
          tz.transition 1987, 9, :o2, 559681200
          tz.transition 1988, 3, :o3, 575406000
          tz.transition 1988, 9, :o2, 591130800
          tz.transition 1989, 3, :o3, 606855600
          tz.transition 1989, 9, :o2, 622580400
          tz.transition 1990, 3, :o3, 638305200
          tz.transition 1990, 9, :o2, 654634800
          tz.transition 1991, 3, :o4, 670359600
          tz.transition 1991, 9, :o1, 686088000
          tz.transition 1992, 1, :o2, 695764800
          tz.transition 1992, 3, :o3, 701798400
          tz.transition 1992, 9, :o2, 717519600
          tz.transition 1993, 3, :o3, 733258800
          tz.transition 1993, 9, :o2, 748983600
          tz.transition 1994, 3, :o3, 764708400
          tz.transition 1994, 9, :o2, 780433200
          tz.transition 1995, 3, :o3, 796158000
          tz.transition 1995, 9, :o2, 811882800
          tz.transition 1996, 3, :o3, 828212400
          tz.transition 1996, 10, :o2, 846356400
          tz.transition 1997, 3, :o3, 859662000
          tz.transition 1997, 10, :o2, 877806000
          tz.transition 1998, 3, :o3, 891111600
          tz.transition 1998, 10, :o2, 909255600
          tz.transition 1999, 3, :o3, 922561200
          tz.transition 1999, 10, :o2, 941310000
          tz.transition 2000, 3, :o3, 954010800
          tz.transition 2000, 10, :o2, 972759600
          tz.transition 2001, 3, :o3, 985460400
          tz.transition 2001, 10, :o2, 1004209200
          tz.transition 2002, 3, :o3, 1017514800
          tz.transition 2002, 10, :o2, 1035658800
          tz.transition 2003, 3, :o3, 1048964400
          tz.transition 2003, 10, :o2, 1067108400
          tz.transition 2004, 3, :o3, 1080414000
          tz.transition 2004, 10, :o2, 1099162800
          tz.transition 2005, 3, :o3, 1111863600
          tz.transition 2005, 10, :o2, 1130612400
          tz.transition 2006, 3, :o3, 1143313200
          tz.transition 2006, 10, :o2, 1162062000
          tz.transition 2007, 3, :o3, 1174762800
          tz.transition 2007, 10, :o2, 1193511600
          tz.transition 2008, 3, :o3, 1206817200
          tz.transition 2008, 10, :o2, 1224961200
          tz.transition 2009, 3, :o3, 1238266800
          tz.transition 2009, 10, :o2, 1256410800
          tz.transition 2010, 3, :o3, 1269716400
          tz.transition 2010, 10, :o2, 1288465200
          tz.transition 2011, 3, :o3, 1301166000
          tz.transition 2011, 10, :o2, 1319914800
          tz.transition 2012, 3, :o3, 1332615600
          tz.transition 2012, 10, :o2, 1351364400
          tz.transition 2013, 3, :o3, 1364670000
          tz.transition 2013, 10, :o2, 1382814000
          tz.transition 2014, 3, :o3, 1396119600
          tz.transition 2014, 10, :o2, 1414263600
          tz.transition 2015, 3, :o3, 1427569200
          tz.transition 2015, 10, :o2, 1445713200
          tz.transition 2016, 3, :o3, 1459018800
          tz.transition 2016, 10, :o2, 1477767600
          tz.transition 2017, 3, :o3, 1490468400
          tz.transition 2017, 10, :o2, 1509217200
          tz.transition 2018, 3, :o3, 1521918000
          tz.transition 2018, 10, :o2, 1540666800
          tz.transition 2019, 3, :o3, 1553972400
          tz.transition 2019, 10, :o2, 1572116400
          tz.transition 2020, 3, :o3, 1585422000
          tz.transition 2020, 10, :o2, 1603566000
          tz.transition 2021, 3, :o3, 1616871600
          tz.transition 2021, 10, :o2, 1635620400
          tz.transition 2022, 3, :o3, 1648321200
          tz.transition 2022, 10, :o2, 1667070000
          tz.transition 2023, 3, :o3, 1679770800
          tz.transition 2023, 10, :o2, 1698519600
          tz.transition 2024, 3, :o3, 1711825200
          tz.transition 2024, 10, :o2, 1729969200
          tz.transition 2025, 3, :o3, 1743274800
          tz.transition 2025, 10, :o2, 1761418800
          tz.transition 2026, 3, :o3, 1774724400
          tz.transition 2026, 10, :o2, 1792868400
          tz.transition 2027, 3, :o3, 1806174000
          tz.transition 2027, 10, :o2, 1824922800
          tz.transition 2028, 3, :o3, 1837623600
          tz.transition 2028, 10, :o2, 1856372400
          tz.transition 2029, 3, :o3, 1869073200
          tz.transition 2029, 10, :o2, 1887822000
          tz.transition 2030, 3, :o3, 1901127600
          tz.transition 2030, 10, :o2, 1919271600
          tz.transition 2031, 3, :o3, 1932577200
          tz.transition 2031, 10, :o2, 1950721200
          tz.transition 2032, 3, :o3, 1964026800
          tz.transition 2032, 10, :o2, 1982775600
          tz.transition 2033, 3, :o3, 1995476400
          tz.transition 2033, 10, :o2, 2014225200
          tz.transition 2034, 3, :o3, 2026926000
          tz.transition 2034, 10, :o2, 2045674800
          tz.transition 2035, 3, :o3, 2058375600
          tz.transition 2035, 10, :o2, 2077124400
          tz.transition 2036, 3, :o3, 2090430000
          tz.transition 2036, 10, :o2, 2108574000
          tz.transition 2037, 3, :o3, 2121879600
          tz.transition 2037, 10, :o2, 2140023600
          tz.transition 2038, 3, :o3, 59172247, 24
          tz.transition 2038, 10, :o2, 59177455, 24
          tz.transition 2039, 3, :o3, 59180983, 24
          tz.transition 2039, 10, :o2, 59186191, 24
          tz.transition 2040, 3, :o3, 59189719, 24
          tz.transition 2040, 10, :o2, 59194927, 24
          tz.transition 2041, 3, :o3, 59198623, 24
          tz.transition 2041, 10, :o2, 59203663, 24
          tz.transition 2042, 3, :o3, 59207359, 24
          tz.transition 2042, 10, :o2, 59212399, 24
          tz.transition 2043, 3, :o3, 59216095, 24
          tz.transition 2043, 10, :o2, 59221135, 24
          tz.transition 2044, 3, :o3, 59224831, 24
          tz.transition 2044, 10, :o2, 59230039, 24
          tz.transition 2045, 3, :o3, 59233567, 24
          tz.transition 2045, 10, :o2, 59238775, 24
          tz.transition 2046, 3, :o3, 59242303, 24
          tz.transition 2046, 10, :o2, 59247511, 24
          tz.transition 2047, 3, :o3, 59251207, 24
          tz.transition 2047, 10, :o2, 59256247, 24
          tz.transition 2048, 3, :o3, 59259943, 24
          tz.transition 2048, 10, :o2, 59264983, 24
          tz.transition 2049, 3, :o3, 59268679, 24
          tz.transition 2049, 10, :o2, 59273887, 24
          tz.transition 2050, 3, :o3, 59277415, 24
          tz.transition 2050, 10, :o2, 59282623, 24
        end
      end
    end
  end
end
