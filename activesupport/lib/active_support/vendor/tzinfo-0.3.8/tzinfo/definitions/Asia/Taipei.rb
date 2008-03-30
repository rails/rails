require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Taipei
        include TimezoneDefinition
        
        timezone 'Asia/Taipei' do |tz|
          tz.offset :o0, 29160, 0, :LMT
          tz.offset :o1, 28800, 0, :CST
          tz.offset :o2, 28800, 3600, :CDT
          
          tz.transition 1895, 12, :o1, 193084733, 80
          tz.transition 1945, 4, :o2, 14589457, 6
          tz.transition 1945, 9, :o1, 19453833, 8
          tz.transition 1946, 4, :o2, 14591647, 6
          tz.transition 1946, 9, :o1, 19456753, 8
          tz.transition 1947, 4, :o2, 14593837, 6
          tz.transition 1947, 9, :o1, 19459673, 8
          tz.transition 1948, 4, :o2, 14596033, 6
          tz.transition 1948, 9, :o1, 19462601, 8
          tz.transition 1949, 4, :o2, 14598223, 6
          tz.transition 1949, 9, :o1, 19465521, 8
          tz.transition 1950, 4, :o2, 14600413, 6
          tz.transition 1950, 9, :o1, 19468441, 8
          tz.transition 1951, 4, :o2, 14602603, 6
          tz.transition 1951, 9, :o1, 19471361, 8
          tz.transition 1952, 2, :o2, 14604433, 6
          tz.transition 1952, 10, :o1, 19474537, 8
          tz.transition 1953, 3, :o2, 14606809, 6
          tz.transition 1953, 10, :o1, 19477457, 8
          tz.transition 1954, 3, :o2, 14608999, 6
          tz.transition 1954, 10, :o1, 19480377, 8
          tz.transition 1955, 3, :o2, 14611189, 6
          tz.transition 1955, 9, :o1, 19483049, 8
          tz.transition 1956, 3, :o2, 14613385, 6
          tz.transition 1956, 9, :o1, 19485977, 8
          tz.transition 1957, 3, :o2, 14615575, 6
          tz.transition 1957, 9, :o1, 19488897, 8
          tz.transition 1958, 3, :o2, 14617765, 6
          tz.transition 1958, 9, :o1, 19491817, 8
          tz.transition 1959, 3, :o2, 14619955, 6
          tz.transition 1959, 9, :o1, 19494737, 8
          tz.transition 1960, 5, :o2, 14622517, 6
          tz.transition 1960, 9, :o1, 19497665, 8
          tz.transition 1961, 5, :o2, 14624707, 6
          tz.transition 1961, 9, :o1, 19500585, 8
          tz.transition 1974, 3, :o2, 133977600
          tz.transition 1974, 9, :o1, 149785200
          tz.transition 1975, 3, :o2, 165513600
          tz.transition 1975, 9, :o1, 181321200
          tz.transition 1980, 6, :o2, 331142400
          tz.transition 1980, 9, :o1, 339087600
        end
      end
    end
  end
end
