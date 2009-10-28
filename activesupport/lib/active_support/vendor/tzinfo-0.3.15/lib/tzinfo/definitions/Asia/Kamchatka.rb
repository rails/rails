require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Kamchatka
        include TimezoneDefinition
        
        timezone 'Asia/Kamchatka' do |tz|
          tz.offset :o0, 38076, 0, :LMT
          tz.offset :o1, 39600, 0, :PETT
          tz.offset :o2, 43200, 0, :PETT
          tz.offset :o3, 43200, 3600, :PETST
          tz.offset :o4, 39600, 3600, :PETST
          
          tz.transition 1922, 11, :o1, 17448250027, 7200
          tz.transition 1930, 6, :o2, 58227553, 24
          tz.transition 1981, 3, :o3, 354888000
          tz.transition 1981, 9, :o2, 370695600
          tz.transition 1982, 3, :o3, 386424000
          tz.transition 1982, 9, :o2, 402231600
          tz.transition 1983, 3, :o3, 417960000
          tz.transition 1983, 9, :o2, 433767600
          tz.transition 1984, 3, :o3, 449582400
          tz.transition 1984, 9, :o2, 465314400
          tz.transition 1985, 3, :o3, 481039200
          tz.transition 1985, 9, :o2, 496764000
          tz.transition 1986, 3, :o3, 512488800
          tz.transition 1986, 9, :o2, 528213600
          tz.transition 1987, 3, :o3, 543938400
          tz.transition 1987, 9, :o2, 559663200
          tz.transition 1988, 3, :o3, 575388000
          tz.transition 1988, 9, :o2, 591112800
          tz.transition 1989, 3, :o3, 606837600
          tz.transition 1989, 9, :o2, 622562400
          tz.transition 1990, 3, :o3, 638287200
          tz.transition 1990, 9, :o2, 654616800
          tz.transition 1991, 3, :o4, 670341600
          tz.transition 1991, 9, :o1, 686070000
          tz.transition 1992, 1, :o2, 695746800
          tz.transition 1992, 3, :o3, 701780400
          tz.transition 1992, 9, :o2, 717501600
          tz.transition 1993, 3, :o3, 733240800
          tz.transition 1993, 9, :o2, 748965600
          tz.transition 1994, 3, :o3, 764690400
          tz.transition 1994, 9, :o2, 780415200
          tz.transition 1995, 3, :o3, 796140000
          tz.transition 1995, 9, :o2, 811864800
          tz.transition 1996, 3, :o3, 828194400
          tz.transition 1996, 10, :o2, 846338400
          tz.transition 1997, 3, :o3, 859644000
          tz.transition 1997, 10, :o2, 877788000
          tz.transition 1998, 3, :o3, 891093600
          tz.transition 1998, 10, :o2, 909237600
          tz.transition 1999, 3, :o3, 922543200
          tz.transition 1999, 10, :o2, 941292000
          tz.transition 2000, 3, :o3, 953992800
          tz.transition 2000, 10, :o2, 972741600
          tz.transition 2001, 3, :o3, 985442400
          tz.transition 2001, 10, :o2, 1004191200
          tz.transition 2002, 3, :o3, 1017496800
          tz.transition 2002, 10, :o2, 1035640800
          tz.transition 2003, 3, :o3, 1048946400
          tz.transition 2003, 10, :o2, 1067090400
          tz.transition 2004, 3, :o3, 1080396000
          tz.transition 2004, 10, :o2, 1099144800
          tz.transition 2005, 3, :o3, 1111845600
          tz.transition 2005, 10, :o2, 1130594400
          tz.transition 2006, 3, :o3, 1143295200
          tz.transition 2006, 10, :o2, 1162044000
          tz.transition 2007, 3, :o3, 1174744800
          tz.transition 2007, 10, :o2, 1193493600
          tz.transition 2008, 3, :o3, 1206799200
          tz.transition 2008, 10, :o2, 1224943200
          tz.transition 2009, 3, :o3, 1238248800
          tz.transition 2009, 10, :o2, 1256392800
          tz.transition 2010, 3, :o3, 1269698400
          tz.transition 2010, 10, :o2, 1288447200
          tz.transition 2011, 3, :o3, 1301148000
          tz.transition 2011, 10, :o2, 1319896800
          tz.transition 2012, 3, :o3, 1332597600
          tz.transition 2012, 10, :o2, 1351346400
          tz.transition 2013, 3, :o3, 1364652000
          tz.transition 2013, 10, :o2, 1382796000
          tz.transition 2014, 3, :o3, 1396101600
          tz.transition 2014, 10, :o2, 1414245600
          tz.transition 2015, 3, :o3, 1427551200
          tz.transition 2015, 10, :o2, 1445695200
          tz.transition 2016, 3, :o3, 1459000800
          tz.transition 2016, 10, :o2, 1477749600
          tz.transition 2017, 3, :o3, 1490450400
          tz.transition 2017, 10, :o2, 1509199200
          tz.transition 2018, 3, :o3, 1521900000
          tz.transition 2018, 10, :o2, 1540648800
          tz.transition 2019, 3, :o3, 1553954400
          tz.transition 2019, 10, :o2, 1572098400
          tz.transition 2020, 3, :o3, 1585404000
          tz.transition 2020, 10, :o2, 1603548000
          tz.transition 2021, 3, :o3, 1616853600
          tz.transition 2021, 10, :o2, 1635602400
          tz.transition 2022, 3, :o3, 1648303200
          tz.transition 2022, 10, :o2, 1667052000
          tz.transition 2023, 3, :o3, 1679752800
          tz.transition 2023, 10, :o2, 1698501600
          tz.transition 2024, 3, :o3, 1711807200
          tz.transition 2024, 10, :o2, 1729951200
          tz.transition 2025, 3, :o3, 1743256800
          tz.transition 2025, 10, :o2, 1761400800
          tz.transition 2026, 3, :o3, 1774706400
          tz.transition 2026, 10, :o2, 1792850400
          tz.transition 2027, 3, :o3, 1806156000
          tz.transition 2027, 10, :o2, 1824904800
          tz.transition 2028, 3, :o3, 1837605600
          tz.transition 2028, 10, :o2, 1856354400
          tz.transition 2029, 3, :o3, 1869055200
          tz.transition 2029, 10, :o2, 1887804000
          tz.transition 2030, 3, :o3, 1901109600
          tz.transition 2030, 10, :o2, 1919253600
          tz.transition 2031, 3, :o3, 1932559200
          tz.transition 2031, 10, :o2, 1950703200
          tz.transition 2032, 3, :o3, 1964008800
          tz.transition 2032, 10, :o2, 1982757600
          tz.transition 2033, 3, :o3, 1995458400
          tz.transition 2033, 10, :o2, 2014207200
          tz.transition 2034, 3, :o3, 2026908000
          tz.transition 2034, 10, :o2, 2045656800
          tz.transition 2035, 3, :o3, 2058357600
          tz.transition 2035, 10, :o2, 2077106400
          tz.transition 2036, 3, :o3, 2090412000
          tz.transition 2036, 10, :o2, 2108556000
          tz.transition 2037, 3, :o3, 2121861600
          tz.transition 2037, 10, :o2, 2140005600
          tz.transition 2038, 3, :o3, 29586121, 12
          tz.transition 2038, 10, :o2, 29588725, 12
          tz.transition 2039, 3, :o3, 29590489, 12
          tz.transition 2039, 10, :o2, 29593093, 12
          tz.transition 2040, 3, :o3, 29594857, 12
          tz.transition 2040, 10, :o2, 29597461, 12
          tz.transition 2041, 3, :o3, 29599309, 12
          tz.transition 2041, 10, :o2, 29601829, 12
          tz.transition 2042, 3, :o3, 29603677, 12
          tz.transition 2042, 10, :o2, 29606197, 12
          tz.transition 2043, 3, :o3, 29608045, 12
          tz.transition 2043, 10, :o2, 29610565, 12
          tz.transition 2044, 3, :o3, 29612413, 12
          tz.transition 2044, 10, :o2, 29615017, 12
          tz.transition 2045, 3, :o3, 29616781, 12
          tz.transition 2045, 10, :o2, 29619385, 12
          tz.transition 2046, 3, :o3, 29621149, 12
          tz.transition 2046, 10, :o2, 29623753, 12
          tz.transition 2047, 3, :o3, 29625601, 12
          tz.transition 2047, 10, :o2, 29628121, 12
          tz.transition 2048, 3, :o3, 29629969, 12
          tz.transition 2048, 10, :o2, 29632489, 12
          tz.transition 2049, 3, :o3, 29634337, 12
          tz.transition 2049, 10, :o2, 29636941, 12
          tz.transition 2050, 3, :o3, 29638705, 12
          tz.transition 2050, 10, :o2, 29641309, 12
        end
      end
    end
  end
end
