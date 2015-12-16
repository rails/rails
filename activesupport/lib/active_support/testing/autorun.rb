gem 'minitest'

require 'minitest'

if Minitest.respond_to?(:run_with_rails_extension)
  unless Minitest.run_with_rails_extension
    Minitest.run_with_autorun = true
    Minitest.autorun
  end
else
  Minitest.autorun
end
