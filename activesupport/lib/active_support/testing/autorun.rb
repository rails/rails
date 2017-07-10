gem 'minitest'

require 'minitest'

if Minitest.respond_to?(:run_via) && !Minitest.run_via.set?
  Minitest.run_via = :ruby
end

Minitest.autorun
