require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Pacific
      module Noumea
        include TimezoneDefinition
        
        timezone 'Pacific/Noumea' do |tz|
          tz.offset :o0, 39948, 0, :LMT
          tz.offset :o1, 39600, 0, :NCT
          tz.offset :o2, 39600, 3600, :NCST
          
          tz.transition 1912, 1, :o1, 17419781071, 7200
          tz.transition 1977, 12, :o2, 250002000
          tz.transition 1978, 2, :o1, 257342400
          tz.transition 1978, 12, :o2, 281451600
          tz.transition 1979, 2, :o1, 288878400
          tz.transition 1996, 11, :o2, 849366000
          tz.transition 1997, 3, :o1, 857228400
        end
      end
    end
  end
end
