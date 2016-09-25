gem "minitest"

require "minitest"

if Minitest.respond_to?(:run_with_rails_extension) && !Minitest.run_with_rails_extension
  Minitest.run_with_autorun = true
end

Minitest.autorun
