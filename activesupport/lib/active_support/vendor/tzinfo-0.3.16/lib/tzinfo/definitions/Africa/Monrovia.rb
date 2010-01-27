require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Africa
      module Monrovia
        include TimezoneDefinition
        
        timezone 'Africa/Monrovia' do |tz|
          tz.offset :o0, -2588, 0, :LMT
          tz.offset :o1, -2588, 0, :MMT
          tz.offset :o2, -2670, 0, :LRT
          tz.offset :o3, 0, 0, :GMT
          
          tz.transition 1882, 1, :o1, 52022445047, 21600
          tz.transition 1919, 3, :o2, 52315600247, 21600
          tz.transition 1972, 5, :o3, 73529070
        end
      end
    end
  end
end
