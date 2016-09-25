gem 'minitest'

require 'minitest'

if Minitest.respond_to?(:run_via) && !Minitest.run_via[:rails]
  Minitest.run_via[:ruby] = true
end

Minitest.autorun
