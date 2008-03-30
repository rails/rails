require 'tzinfo/timezone_definition'

module TZInfo
  module Definitions
    module America
      module Regina
        include TimezoneDefinition
        
        timezone 'America/Regina' do |tz|
          tz.offset :o0, -25116, 0, :LMT
          tz.offset :o1, -25200, 0, :MST
          tz.offset :o2, -25200, 3600, :MDT
          tz.offset :o3, -25200, 3600, :MWT
          tz.offset :o4, -25200, 3600, :MPT
          tz.offset :o5, -21600, 0, :CST
          
          tz.transition 1905, 9, :o1, 17403046493, 7200
          tz.transition 1918, 4, :o2, 19373583, 8
          tz.transition 1918, 10, :o1, 14531387, 6
          tz.transition 1930, 5, :o2, 58226419, 24
          tz.transition 1930, 10, :o1, 9705019, 4
          tz.transition 1931, 5, :o2, 58235155, 24
          tz.transition 1931, 10, :o1, 9706475, 4
          tz.transition 1932, 5, :o2, 58243891, 24
          tz.transition 1932, 10, :o1, 9707931, 4
          tz.transition 1933, 5, :o2, 58252795, 24
          tz.transition 1933, 10, :o1, 9709387, 4
          tz.transition 1934, 5, :o2, 58261531, 24
          tz.transition 1934, 10, :o1, 9710871, 4
          tz.transition 1937, 4, :o2, 58287235, 24
          tz.transition 1937, 10, :o1, 9715267, 4
          tz.transition 1938, 4, :o2, 58295971, 24
          tz.transition 1938, 10, :o1, 9716695, 4
          tz.transition 1939, 4, :o2, 58304707, 24
          tz.transition 1939, 10, :o1, 9718179, 4
          tz.transition 1940, 4, :o2, 58313611, 24
          tz.transition 1940, 10, :o1, 9719663, 4
          tz.transition 1941, 4, :o2, 58322347, 24
          tz.transition 1941, 10, :o1, 9721119, 4
          tz.transition 1942, 2, :o3, 19443199, 8
          tz.transition 1945, 8, :o4, 58360379, 24
          tz.transition 1945, 9, :o1, 14590373, 6
          tz.transition 1946, 4, :o2, 19455399, 8
          tz.transition 1946, 10, :o1, 14592641, 6
          tz.transition 1947, 4, :o2, 19458423, 8
          tz.transition 1947, 9, :o1, 14594741, 6
          tz.transition 1948, 4, :o2, 19461335, 8
          tz.transition 1948, 9, :o1, 14596925, 6
          tz.transition 1949, 4, :o2, 19464247, 8
          tz.transition 1949, 9, :o1, 14599109, 6
          tz.transition 1950, 4, :o2, 19467215, 8
          tz.transition 1950, 9, :o1, 14601293, 6
          tz.transition 1951, 4, :o2, 19470127, 8
          tz.transition 1951, 9, :o1, 14603519, 6
          tz.transition 1952, 4, :o2, 19473039, 8
          tz.transition 1952, 9, :o1, 14605703, 6
          tz.transition 1953, 4, :o2, 19475951, 8
          tz.transition 1953, 9, :o1, 14607887, 6
          tz.transition 1954, 4, :o2, 19478863, 8
          tz.transition 1954, 9, :o1, 14610071, 6
          tz.transition 1955, 4, :o2, 19481775, 8
          tz.transition 1955, 9, :o1, 14612255, 6
          tz.transition 1956, 4, :o2, 19484743, 8
          tz.transition 1956, 9, :o1, 14614481, 6
          tz.transition 1957, 4, :o2, 19487655, 8
          tz.transition 1957, 9, :o1, 14616665, 6
          tz.transition 1959, 4, :o2, 19493479, 8
          tz.transition 1959, 10, :o1, 14621201, 6
          tz.transition 1960, 4, :o5, 19496391, 8
        end
      end
    end
  end
end
