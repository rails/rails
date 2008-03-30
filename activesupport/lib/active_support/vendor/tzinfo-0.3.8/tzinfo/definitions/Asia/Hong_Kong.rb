require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module Asia
      module Hong_Kong
        include TimezoneDefinition
        
        timezone 'Asia/Hong_Kong' do |tz|
          tz.offset :o0, 27396, 0, :LMT
          tz.offset :o1, 28800, 0, :HKT
          tz.offset :o2, 28800, 3600, :HKST
          
          tz.transition 1904, 10, :o1, 5800279639, 2400
          tz.transition 1946, 4, :o2, 38910885, 16
          tz.transition 1946, 11, :o1, 116743453, 48
          tz.transition 1947, 4, :o2, 38916613, 16
          tz.transition 1947, 12, :o1, 116762365, 48
          tz.transition 1948, 5, :o2, 38922773, 16
          tz.transition 1948, 10, :o1, 116777053, 48
          tz.transition 1949, 4, :o2, 38928149, 16
          tz.transition 1949, 10, :o1, 116794525, 48
          tz.transition 1950, 4, :o2, 38933973, 16
          tz.transition 1950, 10, :o1, 116811997, 48
          tz.transition 1951, 3, :o2, 38939797, 16
          tz.transition 1951, 10, :o1, 116829469, 48
          tz.transition 1952, 4, :o2, 38945733, 16
          tz.transition 1952, 10, :o1, 116846941, 48
          tz.transition 1953, 4, :o2, 38951557, 16
          tz.transition 1953, 10, :o1, 116864749, 48
          tz.transition 1954, 3, :o2, 38957157, 16
          tz.transition 1954, 10, :o1, 116882221, 48
          tz.transition 1955, 3, :o2, 38962981, 16
          tz.transition 1955, 11, :o1, 116900029, 48
          tz.transition 1956, 3, :o2, 38968805, 16
          tz.transition 1956, 11, :o1, 116917501, 48
          tz.transition 1957, 3, :o2, 38974741, 16
          tz.transition 1957, 11, :o1, 116934973, 48
          tz.transition 1958, 3, :o2, 38980565, 16
          tz.transition 1958, 11, :o1, 116952445, 48
          tz.transition 1959, 3, :o2, 38986389, 16
          tz.transition 1959, 10, :o1, 116969917, 48
          tz.transition 1960, 3, :o2, 38992213, 16
          tz.transition 1960, 11, :o1, 116987725, 48
          tz.transition 1961, 3, :o2, 38998037, 16
          tz.transition 1961, 11, :o1, 117005197, 48
          tz.transition 1962, 3, :o2, 39003861, 16
          tz.transition 1962, 11, :o1, 117022669, 48
          tz.transition 1963, 3, :o2, 39009797, 16
          tz.transition 1963, 11, :o1, 117040141, 48
          tz.transition 1964, 3, :o2, 39015621, 16
          tz.transition 1964, 10, :o1, 117057613, 48
          tz.transition 1965, 4, :o2, 39021893, 16
          tz.transition 1965, 10, :o1, 117074413, 48
          tz.transition 1966, 4, :o2, 39027717, 16
          tz.transition 1966, 10, :o1, 117091885, 48
          tz.transition 1967, 4, :o2, 39033541, 16
          tz.transition 1967, 10, :o1, 117109693, 48
          tz.transition 1968, 4, :o2, 39039477, 16
          tz.transition 1968, 10, :o1, 117127165, 48
          tz.transition 1969, 4, :o2, 39045301, 16
          tz.transition 1969, 10, :o1, 117144637, 48
          tz.transition 1970, 4, :o2, 9315000
          tz.transition 1970, 10, :o1, 25036200
          tz.transition 1971, 4, :o2, 40764600
          tz.transition 1971, 10, :o1, 56485800
          tz.transition 1972, 4, :o2, 72214200
          tz.transition 1972, 10, :o1, 88540200
          tz.transition 1973, 4, :o2, 104268600
          tz.transition 1973, 10, :o1, 119989800
          tz.transition 1974, 4, :o2, 135718200
          tz.transition 1974, 10, :o1, 151439400
          tz.transition 1975, 4, :o2, 167167800
          tz.transition 1975, 10, :o1, 182889000
          tz.transition 1976, 4, :o2, 198617400
          tz.transition 1976, 10, :o1, 214338600
          tz.transition 1977, 4, :o2, 230067000
          tz.transition 1977, 10, :o1, 245788200
          tz.transition 1979, 5, :o2, 295385400
          tz.transition 1979, 10, :o1, 309292200
          tz.transition 1980, 5, :o2, 326835000
          tz.transition 1980, 10, :o1, 340741800
        end
      end
    end
  end
end
