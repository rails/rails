require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Pacific
      module Pago_Pago
        include TimezoneDefinition
        
        timezone 'Pacific/Pago_Pago' do |tz|
          tz.offset :o0, 45432, 0, :LMT
          tz.offset :o1, -40968, 0, :LMT
          tz.offset :o2, -41400, 0, :SAMT
          tz.offset :o3, -39600, 0, :NST
          tz.offset :o4, -39600, 0, :BST
          tz.offset :o5, -39600, 0, :SST
          
          tz.transition 1879, 7, :o1, 2889041969, 1200
          tz.transition 1911, 1, :o2, 2902845569, 1200
          tz.transition 1950, 1, :o3, 116797583, 48
          tz.transition 1967, 4, :o4, 58549967, 24
          tz.transition 1983, 11, :o5, 439038000
        end
      end
    end
  end
end
