require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Australia
      module Sydney
        include TimezoneDefinition
        
        timezone 'Australia/Sydney' do |tz|
          tz.offset :o0, 36292, 0, :LMT
          tz.offset :o1, 36000, 0, :EST
          tz.offset :o2, 36000, 3600, :EST
          
          tz.transition 1895, 1, :o1, 52125661727, 21600
          tz.transition 1916, 12, :o2, 3486569881, 1440
          tz.transition 1917, 3, :o1, 19370497, 8
          tz.transition 1941, 12, :o2, 14582161, 6
          tz.transition 1942, 3, :o1, 19443577, 8
          tz.transition 1942, 9, :o2, 14583775, 6
          tz.transition 1943, 3, :o1, 19446489, 8
          tz.transition 1943, 10, :o2, 14586001, 6
          tz.transition 1944, 3, :o1, 19449401, 8
          tz.transition 1971, 10, :o2, 57686400
          tz.transition 1972, 2, :o1, 67968000
          tz.transition 1972, 10, :o2, 89136000
          tz.transition 1973, 3, :o1, 100022400
          tz.transition 1973, 10, :o2, 120585600
          tz.transition 1974, 3, :o1, 131472000
          tz.transition 1974, 10, :o2, 152035200
          tz.transition 1975, 3, :o1, 162921600
          tz.transition 1975, 10, :o2, 183484800
          tz.transition 1976, 3, :o1, 194976000
          tz.transition 1976, 10, :o2, 215539200
          tz.transition 1977, 3, :o1, 226425600
          tz.transition 1977, 10, :o2, 246988800
          tz.transition 1978, 3, :o1, 257875200
          tz.transition 1978, 10, :o2, 278438400
          tz.transition 1979, 3, :o1, 289324800
          tz.transition 1979, 10, :o2, 309888000
          tz.transition 1980, 3, :o1, 320774400
          tz.transition 1980, 10, :o2, 341337600
          tz.transition 1981, 2, :o1, 352224000
          tz.transition 1981, 10, :o2, 372787200
          tz.transition 1982, 4, :o1, 386697600
          tz.transition 1982, 10, :o2, 404841600
          tz.transition 1983, 3, :o1, 415728000
          tz.transition 1983, 10, :o2, 436291200
          tz.transition 1984, 3, :o1, 447177600
          tz.transition 1984, 10, :o2, 467740800
          tz.transition 1985, 3, :o1, 478627200
          tz.transition 1985, 10, :o2, 499190400
          tz.transition 1986, 3, :o1, 511286400
          tz.transition 1986, 10, :o2, 530035200
          tz.transition 1987, 3, :o1, 542736000
          tz.transition 1987, 10, :o2, 562089600
          tz.transition 1988, 3, :o1, 574790400
          tz.transition 1988, 10, :o2, 594144000
          tz.transition 1989, 3, :o1, 606240000
          tz.transition 1989, 10, :o2, 625593600
          tz.transition 1990, 3, :o1, 636480000
          tz.transition 1990, 10, :o2, 657043200
          tz.transition 1991, 3, :o1, 667929600
          tz.transition 1991, 10, :o2, 688492800
          tz.transition 1992, 2, :o1, 699379200
          tz.transition 1992, 10, :o2, 719942400
          tz.transition 1993, 3, :o1, 731433600
          tz.transition 1993, 10, :o2, 751996800
          tz.transition 1994, 3, :o1, 762883200
          tz.transition 1994, 10, :o2, 783446400
          tz.transition 1995, 3, :o1, 794332800
          tz.transition 1995, 10, :o2, 814896000
          tz.transition 1996, 3, :o1, 828201600
          tz.transition 1996, 10, :o2, 846345600
          tz.transition 1997, 3, :o1, 859651200
          tz.transition 1997, 10, :o2, 877795200
          tz.transition 1998, 3, :o1, 891100800
          tz.transition 1998, 10, :o2, 909244800
          tz.transition 1999, 3, :o1, 922550400
          tz.transition 1999, 10, :o2, 941299200
          tz.transition 2000, 3, :o1, 954000000
          tz.transition 2000, 8, :o2, 967305600
          tz.transition 2001, 3, :o1, 985449600
          tz.transition 2001, 10, :o2, 1004198400
          tz.transition 2002, 3, :o1, 1017504000
          tz.transition 2002, 10, :o2, 1035648000
          tz.transition 2003, 3, :o1, 1048953600
          tz.transition 2003, 10, :o2, 1067097600
          tz.transition 2004, 3, :o1, 1080403200
          tz.transition 2004, 10, :o2, 1099152000
          tz.transition 2005, 3, :o1, 1111852800
          tz.transition 2005, 10, :o2, 1130601600
          tz.transition 2006, 4, :o1, 1143907200
          tz.transition 2006, 10, :o2, 1162051200
          tz.transition 2007, 3, :o1, 1174752000
          tz.transition 2007, 10, :o2, 1193500800
          tz.transition 2008, 4, :o1, 1207411200
          tz.transition 2008, 10, :o2, 1223136000
          tz.transition 2009, 4, :o1, 1238860800
          tz.transition 2009, 10, :o2, 1254585600
          tz.transition 2010, 4, :o1, 1270310400
          tz.transition 2010, 10, :o2, 1286035200
          tz.transition 2011, 4, :o1, 1301760000
          tz.transition 2011, 10, :o2, 1317484800
          tz.transition 2012, 3, :o1, 1333209600
          tz.transition 2012, 10, :o2, 1349539200
          tz.transition 2013, 4, :o1, 1365264000
          tz.transition 2013, 10, :o2, 1380988800
          tz.transition 2014, 4, :o1, 1396713600
          tz.transition 2014, 10, :o2, 1412438400
          tz.transition 2015, 4, :o1, 1428163200
          tz.transition 2015, 10, :o2, 1443888000
          tz.transition 2016, 4, :o1, 1459612800
          tz.transition 2016, 10, :o2, 1475337600
          tz.transition 2017, 4, :o1, 1491062400
          tz.transition 2017, 9, :o2, 1506787200
          tz.transition 2018, 3, :o1, 1522512000
          tz.transition 2018, 10, :o2, 1538841600
          tz.transition 2019, 4, :o1, 1554566400
          tz.transition 2019, 10, :o2, 1570291200
          tz.transition 2020, 4, :o1, 1586016000
          tz.transition 2020, 10, :o2, 1601740800
          tz.transition 2021, 4, :o1, 1617465600
          tz.transition 2021, 10, :o2, 1633190400
          tz.transition 2022, 4, :o1, 1648915200
          tz.transition 2022, 10, :o2, 1664640000
          tz.transition 2023, 4, :o1, 1680364800
          tz.transition 2023, 9, :o2, 1696089600
          tz.transition 2024, 4, :o1, 1712419200
          tz.transition 2024, 10, :o2, 1728144000
          tz.transition 2025, 4, :o1, 1743868800
          tz.transition 2025, 10, :o2, 1759593600
          tz.transition 2026, 4, :o1, 1775318400
          tz.transition 2026, 10, :o2, 1791043200
          tz.transition 2027, 4, :o1, 1806768000
          tz.transition 2027, 10, :o2, 1822492800
          tz.transition 2028, 4, :o1, 1838217600
          tz.transition 2028, 9, :o2, 1853942400
          tz.transition 2029, 3, :o1, 1869667200
          tz.transition 2029, 10, :o2, 1885996800
          tz.transition 2030, 4, :o1, 1901721600
          tz.transition 2030, 10, :o2, 1917446400
          tz.transition 2031, 4, :o1, 1933171200
          tz.transition 2031, 10, :o2, 1948896000
          tz.transition 2032, 4, :o1, 1964620800
          tz.transition 2032, 10, :o2, 1980345600
          tz.transition 2033, 4, :o1, 1996070400
          tz.transition 2033, 10, :o2, 2011795200
          tz.transition 2034, 4, :o1, 2027520000
          tz.transition 2034, 9, :o2, 2043244800
          tz.transition 2035, 3, :o1, 2058969600
          tz.transition 2035, 10, :o2, 2075299200
          tz.transition 2036, 4, :o1, 2091024000
          tz.transition 2036, 10, :o2, 2106748800
          tz.transition 2037, 4, :o1, 2122473600
          tz.transition 2037, 10, :o2, 2138198400
          tz.transition 2038, 4, :o1, 14793103, 6
          tz.transition 2038, 10, :o2, 14794195, 6
          tz.transition 2039, 4, :o1, 14795287, 6
          tz.transition 2039, 10, :o2, 14796379, 6
          tz.transition 2040, 3, :o1, 14797471, 6
          tz.transition 2040, 10, :o2, 14798605, 6
          tz.transition 2041, 4, :o1, 14799697, 6
          tz.transition 2041, 10, :o2, 14800789, 6
          tz.transition 2042, 4, :o1, 14801881, 6
          tz.transition 2042, 10, :o2, 14802973, 6
          tz.transition 2043, 4, :o1, 14804065, 6
          tz.transition 2043, 10, :o2, 14805157, 6
          tz.transition 2044, 4, :o1, 14806249, 6
          tz.transition 2044, 10, :o2, 14807341, 6
          tz.transition 2045, 4, :o1, 14808433, 6
          tz.transition 2045, 9, :o2, 14809525, 6
          tz.transition 2046, 3, :o1, 14810617, 6
          tz.transition 2046, 10, :o2, 14811751, 6
          tz.transition 2047, 4, :o1, 14812843, 6
          tz.transition 2047, 10, :o2, 14813935, 6
          tz.transition 2048, 4, :o1, 14815027, 6
          tz.transition 2048, 10, :o2, 14816119, 6
          tz.transition 2049, 4, :o1, 14817211, 6
          tz.transition 2049, 10, :o2, 14818303, 6
          tz.transition 2050, 4, :o1, 14819395, 6
        end
      end
    end
  end
end
