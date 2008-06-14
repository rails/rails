require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Seoul
        include TimezoneDefinition
        
        timezone 'Asia/Seoul' do |tz|
          tz.offset :o0, 30472, 0, :LMT
          tz.offset :o1, 30600, 0, :KST
          tz.offset :o2, 32400, 0, :KST
          tz.offset :o3, 28800, 0, :KST
          tz.offset :o4, 28800, 3600, :KDT
          tz.offset :o5, 32400, 3600, :KDT
          
          tz.transition 1889, 12, :o1, 26042775991, 10800
          tz.transition 1904, 11, :o2, 116007127, 48
          tz.transition 1927, 12, :o1, 19401969, 8
          tz.transition 1931, 12, :o2, 116481943, 48
          tz.transition 1954, 3, :o3, 19478577, 8
          tz.transition 1960, 5, :o4, 14622415, 6
          tz.transition 1960, 9, :o3, 19497521, 8
          tz.transition 1961, 8, :o1, 14625127, 6
          tz.transition 1968, 9, :o2, 117126247, 48
          tz.transition 1987, 5, :o5, 547570800
          tz.transition 1987, 10, :o2, 560872800
          tz.transition 1988, 5, :o5, 579020400
          tz.transition 1988, 10, :o2, 592322400
        end
      end
    end
  end
end
