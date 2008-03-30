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
        end
      end
    end
  end
end
