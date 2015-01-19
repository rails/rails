gem 'minitest'

require 'minitest'

unless Rails::TestRunner.running?
  Minitest.autorun
end
