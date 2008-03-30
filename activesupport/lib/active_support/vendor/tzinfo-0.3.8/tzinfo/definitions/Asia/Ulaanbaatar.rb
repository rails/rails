require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Ulaanbaatar
        include TimezoneDefinition
        
        timezone 'Asia/Ulaanbaatar' do |tz|
          tz.offset :o0, 25652, 0, :LMT
          tz.offset :o1, 25200, 0, :ULAT
          tz.offset :o2, 28800, 0, :ULAT
          tz.offset :o3, 28800, 3600, :ULAST
          
          tz.transition 1905, 7, :o1, 52208457187, 21600
          tz.transition 1977, 12, :o2, 252435600
          tz.transition 1983, 3, :o3, 417974400
          tz.transition 1983, 9, :o2, 433782000
          tz.transition 1984, 3, :o3, 449596800
          tz.transition 1984, 9, :o2, 465318000
          tz.transition 1985, 3, :o3, 481046400
          tz.transition 1985, 9, :o2, 496767600
          tz.transition 1986, 3, :o3, 512496000
          tz.transition 1986, 9, :o2, 528217200
          tz.transition 1987, 3, :o3, 543945600
          tz.transition 1987, 9, :o2, 559666800
          tz.transition 1988, 3, :o3, 575395200
          tz.transition 1988, 9, :o2, 591116400
          tz.transition 1989, 3, :o3, 606844800
          tz.transition 1989, 9, :o2, 622566000
          tz.transition 1990, 3, :o3, 638294400
          tz.transition 1990, 9, :o2, 654620400
          tz.transition 1991, 3, :o3, 670348800
          tz.transition 1991, 9, :o2, 686070000
          tz.transition 1992, 3, :o3, 701798400
          tz.transition 1992, 9, :o2, 717519600
          tz.transition 1993, 3, :o3, 733248000
          tz.transition 1993, 9, :o2, 748969200
          tz.transition 1994, 3, :o3, 764697600
          tz.transition 1994, 9, :o2, 780418800
          tz.transition 1995, 3, :o3, 796147200
          tz.transition 1995, 9, :o2, 811868400
          tz.transition 1996, 3, :o3, 828201600
          tz.transition 1996, 9, :o2, 843922800
          tz.transition 1997, 3, :o3, 859651200
          tz.transition 1997, 9, :o2, 875372400
          tz.transition 1998, 3, :o3, 891100800
          tz.transition 1998, 9, :o2, 906822000
          tz.transition 2001, 4, :o3, 988394400
          tz.transition 2001, 9, :o2, 1001696400
          tz.transition 2002, 3, :o3, 1017424800
          tz.transition 2002, 9, :o2, 1033146000
          tz.transition 2003, 3, :o3, 1048874400
          tz.transition 2003, 9, :o2, 1064595600
          tz.transition 2004, 3, :o3, 1080324000
          tz.transition 2004, 9, :o2, 1096045200
          tz.transition 2005, 3, :o3, 1111773600
          tz.transition 2005, 9, :o2, 1127494800
          tz.transition 2006, 3, :o3, 1143223200
          tz.transition 2006, 9, :o2, 1159549200
        end
      end
    end
  end
end
