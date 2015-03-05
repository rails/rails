gem 'minitest'

require 'minitest'

unless defined? Rails::TestRunner
  Minitest.autorun
end
