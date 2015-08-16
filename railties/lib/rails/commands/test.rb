require 'rails/test_unit/minitest_plugin'
require 'rails/commands/command'

module Rails
  module Commands
    class Test < Command
      rake_delegate 'test', 'test:db'

      set_banner :test, 'Runs all tests in test folder'
      set_banner :test_db, 'Run tests quickly, but also reset db'
    end
  end
end
