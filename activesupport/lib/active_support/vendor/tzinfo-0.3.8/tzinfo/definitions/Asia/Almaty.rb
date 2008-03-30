require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Almaty
        include TimezoneDefinition
        
        timezone 'Asia/Almaty' do |tz|
          tz.offset :o0, 18468, 0, :LMT
          tz.offset :o1, 18000, 0, :ALMT
          tz.offset :o2, 21600, 0, :ALMT
          tz.offset :o3, 21600, 3600, :ALMST
          
          tz.transition 1924, 5, :o1, 1939125829, 800
          tz.transition 1930, 6, :o2, 58227559, 24
          tz.transition 1981, 3, :o3, 354909600
          tz.transition 1981, 9, :o2, 370717200
          tz.transition 1982, 3, :o3, 386445600
          tz.transition 1982, 9, :o2, 402253200
          tz.transition 1983, 3, :o3, 417981600
          tz.transition 1983, 9, :o2, 433789200
          tz.transition 1984, 3, :o3, 449604000
          tz.transition 1984, 9, :o2, 465336000
          tz.transition 1985, 3, :o3, 481060800
          tz.transition 1985, 9, :o2, 496785600
          tz.transition 1986, 3, :o3, 512510400
          tz.transition 1986, 9, :o2, 528235200
          tz.transition 1987, 3, :o3, 543960000
          tz.transition 1987, 9, :o2, 559684800
          tz.transition 1988, 3, :o3, 575409600
          tz.transition 1988, 9, :o2, 591134400
          tz.transition 1989, 3, :o3, 606859200
          tz.transition 1989, 9, :o2, 622584000
          tz.transition 1990, 3, :o3, 638308800
          tz.transition 1990, 9, :o2, 654638400
          tz.transition 1992, 3, :o3, 701802000
          tz.transition 1992, 9, :o2, 717523200
          tz.transition 1993, 3, :o3, 733262400
          tz.transition 1993, 9, :o2, 748987200
          tz.transition 1994, 3, :o3, 764712000
          tz.transition 1994, 9, :o2, 780436800
          tz.transition 1995, 3, :o3, 796161600
          tz.transition 1995, 9, :o2, 811886400
          tz.transition 1996, 3, :o3, 828216000
          tz.transition 1996, 10, :o2, 846360000
          tz.transition 1997, 3, :o3, 859665600
          tz.transition 1997, 10, :o2, 877809600
          tz.transition 1998, 3, :o3, 891115200
          tz.transition 1998, 10, :o2, 909259200
          tz.transition 1999, 3, :o3, 922564800
          tz.transition 1999, 10, :o2, 941313600
          tz.transition 2000, 3, :o3, 954014400
          tz.transition 2000, 10, :o2, 972763200
          tz.transition 2001, 3, :o3, 985464000
          tz.transition 2001, 10, :o2, 1004212800
          tz.transition 2002, 3, :o3, 1017518400
          tz.transition 2002, 10, :o2, 1035662400
          tz.transition 2003, 3, :o3, 1048968000
          tz.transition 2003, 10, :o2, 1067112000
          tz.transition 2004, 3, :o3, 1080417600
          tz.transition 2004, 10, :o2, 1099166400
        end
      end
    end
  end
end
