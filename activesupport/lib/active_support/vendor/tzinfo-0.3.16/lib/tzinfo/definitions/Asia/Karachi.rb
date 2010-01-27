require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Karachi
        include TimezoneDefinition
        
        timezone 'Asia/Karachi' do |tz|
          tz.offset :o0, 16092, 0, :LMT
          tz.offset :o1, 19800, 0, :IST
          tz.offset :o2, 19800, 3600, :IST
          tz.offset :o3, 18000, 0, :KART
          tz.offset :o4, 18000, 0, :PKT
          tz.offset :o5, 18000, 3600, :PKST
          
          tz.transition 1906, 12, :o1, 1934061051, 800
          tz.transition 1942, 8, :o2, 116668957, 48
          tz.transition 1945, 10, :o1, 116723675, 48
          tz.transition 1951, 9, :o3, 116828125, 48
          tz.transition 1971, 3, :o4, 38775600
          tz.transition 2002, 4, :o5, 1018119660
          tz.transition 2002, 10, :o4, 1033840860
          tz.transition 2008, 5, :o5, 1212260400
          tz.transition 2008, 10, :o4, 1225476000
          tz.transition 2009, 4, :o5, 1239735600
          tz.transition 2009, 10, :o4, 1257012000
          tz.transition 2010, 4, :o5, 1271271600
          tz.transition 2010, 10, :o4, 1288548000
          tz.transition 2011, 4, :o5, 1302807600
          tz.transition 2011, 10, :o4, 1320084000
          tz.transition 2012, 4, :o5, 1334430000
          tz.transition 2012, 10, :o4, 1351706400
          tz.transition 2013, 4, :o5, 1365966000
          tz.transition 2013, 10, :o4, 1383242400
          tz.transition 2014, 4, :o5, 1397502000
          tz.transition 2014, 10, :o4, 1414778400
          tz.transition 2015, 4, :o5, 1429038000
          tz.transition 2015, 10, :o4, 1446314400
          tz.transition 2016, 4, :o5, 1460660400
          tz.transition 2016, 10, :o4, 1477936800
          tz.transition 2017, 4, :o5, 1492196400
          tz.transition 2017, 10, :o4, 1509472800
          tz.transition 2018, 4, :o5, 1523732400
          tz.transition 2018, 10, :o4, 1541008800
          tz.transition 2019, 4, :o5, 1555268400
          tz.transition 2019, 10, :o4, 1572544800
          tz.transition 2020, 4, :o5, 1586890800
          tz.transition 2020, 10, :o4, 1604167200
          tz.transition 2021, 4, :o5, 1618426800
          tz.transition 2021, 10, :o4, 1635703200
          tz.transition 2022, 4, :o5, 1649962800
          tz.transition 2022, 10, :o4, 1667239200
          tz.transition 2023, 4, :o5, 1681498800
          tz.transition 2023, 10, :o4, 1698775200
          tz.transition 2024, 4, :o5, 1713121200
          tz.transition 2024, 10, :o4, 1730397600
          tz.transition 2025, 4, :o5, 1744657200
          tz.transition 2025, 10, :o4, 1761933600
          tz.transition 2026, 4, :o5, 1776193200
          tz.transition 2026, 10, :o4, 1793469600
          tz.transition 2027, 4, :o5, 1807729200
          tz.transition 2027, 10, :o4, 1825005600
          tz.transition 2028, 4, :o5, 1839351600
          tz.transition 2028, 10, :o4, 1856628000
          tz.transition 2029, 4, :o5, 1870887600
          tz.transition 2029, 10, :o4, 1888164000
          tz.transition 2030, 4, :o5, 1902423600
          tz.transition 2030, 10, :o4, 1919700000
          tz.transition 2031, 4, :o5, 1933959600
          tz.transition 2031, 10, :o4, 1951236000
          tz.transition 2032, 4, :o5, 1965582000
          tz.transition 2032, 10, :o4, 1982858400
          tz.transition 2033, 4, :o5, 1997118000
          tz.transition 2033, 10, :o4, 2014394400
          tz.transition 2034, 4, :o5, 2028654000
          tz.transition 2034, 10, :o4, 2045930400
          tz.transition 2035, 4, :o5, 2060190000
          tz.transition 2035, 10, :o4, 2077466400
          tz.transition 2036, 4, :o5, 2091812400
          tz.transition 2036, 10, :o4, 2109088800
          tz.transition 2037, 4, :o5, 2123348400
          tz.transition 2037, 10, :o4, 2140624800
          tz.transition 2038, 4, :o5, 59172679, 24
          tz.transition 2038, 10, :o4, 9862913, 4
          tz.transition 2039, 4, :o5, 59181439, 24
          tz.transition 2039, 10, :o4, 9864373, 4
          tz.transition 2040, 4, :o5, 59190223, 24
          tz.transition 2040, 10, :o4, 9865837, 4
          tz.transition 2041, 4, :o5, 59198983, 24
          tz.transition 2041, 10, :o4, 9867297, 4
          tz.transition 2042, 4, :o5, 59207743, 24
          tz.transition 2042, 10, :o4, 9868757, 4
          tz.transition 2043, 4, :o5, 59216503, 24
          tz.transition 2043, 10, :o4, 9870217, 4
          tz.transition 2044, 4, :o5, 59225287, 24
          tz.transition 2044, 10, :o4, 9871681, 4
          tz.transition 2045, 4, :o5, 59234047, 24
          tz.transition 2045, 10, :o4, 9873141, 4
          tz.transition 2046, 4, :o5, 59242807, 24
          tz.transition 2046, 10, :o4, 9874601, 4
          tz.transition 2047, 4, :o5, 59251567, 24
          tz.transition 2047, 10, :o4, 9876061, 4
          tz.transition 2048, 4, :o5, 59260351, 24
          tz.transition 2048, 10, :o4, 9877525, 4
          tz.transition 2049, 4, :o5, 59269111, 24
          tz.transition 2049, 10, :o4, 9878985, 4
          tz.transition 2050, 4, :o5, 59277871, 24
          tz.transition 2050, 10, :o4, 9880445, 4
        end
      end
    end
  end
end
