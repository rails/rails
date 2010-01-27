require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Tashkent
        include TimezoneDefinition
        
        timezone 'Asia/Tashkent' do |tz|
          tz.offset :o0, 16632, 0, :LMT
          tz.offset :o1, 18000, 0, :TAST
          tz.offset :o2, 21600, 0, :TAST
          tz.offset :o3, 21600, 3600, :TASST
          tz.offset :o4, 18000, 3600, :TASST
          tz.offset :o5, 18000, 3600, :UZST
          tz.offset :o6, 18000, 0, :UZT
          
          tz.transition 1924, 5, :o1, 969562923, 400
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
          tz.transition 1991, 3, :o4, 670363200
          tz.transition 1991, 8, :o5, 683661600
          tz.transition 1991, 9, :o6, 686091600
        end
      end
    end
  end
end
