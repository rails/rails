require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Baghdad
        include TimezoneDefinition
        
        timezone 'Asia/Baghdad' do |tz|
          tz.offset :o0, 10660, 0, :LMT
          tz.offset :o1, 10656, 0, :BMT
          tz.offset :o2, 10800, 0, :AST
          tz.offset :o3, 10800, 3600, :ADT
          
          tz.transition 1889, 12, :o1, 10417111387, 4320
          tz.transition 1917, 12, :o2, 726478313, 300
          tz.transition 1982, 4, :o3, 389048400
          tz.transition 1982, 9, :o2, 402264000
          tz.transition 1983, 3, :o3, 417906000
          tz.transition 1983, 9, :o2, 433800000
          tz.transition 1984, 3, :o3, 449614800
          tz.transition 1984, 9, :o2, 465422400
          tz.transition 1985, 3, :o3, 481150800
          tz.transition 1985, 9, :o2, 496792800
          tz.transition 1986, 3, :o3, 512517600
          tz.transition 1986, 9, :o2, 528242400
          tz.transition 1987, 3, :o3, 543967200
          tz.transition 1987, 9, :o2, 559692000
          tz.transition 1988, 3, :o3, 575416800
          tz.transition 1988, 9, :o2, 591141600
          tz.transition 1989, 3, :o3, 606866400
          tz.transition 1989, 9, :o2, 622591200
          tz.transition 1990, 3, :o3, 638316000
          tz.transition 1990, 9, :o2, 654645600
          tz.transition 1991, 4, :o3, 670464000
          tz.transition 1991, 10, :o2, 686275200
          tz.transition 1992, 4, :o3, 702086400
          tz.transition 1992, 10, :o2, 717897600
          tz.transition 1993, 4, :o3, 733622400
          tz.transition 1993, 10, :o2, 749433600
          tz.transition 1994, 4, :o3, 765158400
          tz.transition 1994, 10, :o2, 780969600
          tz.transition 1995, 4, :o3, 796694400
          tz.transition 1995, 10, :o2, 812505600
          tz.transition 1996, 4, :o3, 828316800
          tz.transition 1996, 10, :o2, 844128000
          tz.transition 1997, 4, :o3, 859852800
          tz.transition 1997, 10, :o2, 875664000
          tz.transition 1998, 4, :o3, 891388800
          tz.transition 1998, 10, :o2, 907200000
          tz.transition 1999, 4, :o3, 922924800
          tz.transition 1999, 10, :o2, 938736000
          tz.transition 2000, 4, :o3, 954547200
          tz.transition 2000, 10, :o2, 970358400
          tz.transition 2001, 4, :o3, 986083200
          tz.transition 2001, 10, :o2, 1001894400
          tz.transition 2002, 4, :o3, 1017619200
          tz.transition 2002, 10, :o2, 1033430400
          tz.transition 2003, 4, :o3, 1049155200
          tz.transition 2003, 10, :o2, 1064966400
          tz.transition 2004, 4, :o3, 1080777600
          tz.transition 2004, 10, :o2, 1096588800
          tz.transition 2005, 4, :o3, 1112313600
          tz.transition 2005, 10, :o2, 1128124800
          tz.transition 2006, 4, :o3, 1143849600
          tz.transition 2006, 10, :o2, 1159660800
          tz.transition 2007, 4, :o3, 1175385600
          tz.transition 2007, 10, :o2, 1191196800
        end
      end
    end
  end
end
