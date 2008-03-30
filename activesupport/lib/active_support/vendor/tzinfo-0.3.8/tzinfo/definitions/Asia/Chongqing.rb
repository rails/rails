require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Chongqing
        include TimezoneDefinition
        
        timezone 'Asia/Chongqing' do |tz|
          tz.offset :o0, 25580, 0, :LMT
          tz.offset :o1, 25200, 0, :LONT
          tz.offset :o2, 28800, 0, :CST
          tz.offset :o3, 28800, 3600, :CDT
          
          tz.transition 1927, 12, :o1, 10477063601, 4320
          tz.transition 1980, 4, :o2, 325962000
          tz.transition 1986, 5, :o3, 515520000
          tz.transition 1986, 9, :o2, 527007600
          tz.transition 1987, 4, :o3, 545155200
          tz.transition 1987, 9, :o2, 558457200
          tz.transition 1988, 4, :o3, 576604800
          tz.transition 1988, 9, :o2, 589906800
          tz.transition 1989, 4, :o3, 608659200
          tz.transition 1989, 9, :o2, 621961200
          tz.transition 1990, 4, :o3, 640108800
          tz.transition 1990, 9, :o2, 653410800
          tz.transition 1991, 4, :o3, 671558400
          tz.transition 1991, 9, :o2, 684860400
        end
      end
    end
  end
end
