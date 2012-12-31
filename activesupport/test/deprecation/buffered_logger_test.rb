require 'abstract_unit'
require 'active_support/buffered_logger'

class BufferedLoggerTest < ActiveSupport::TestCase

  def test_can_be_subclassed
    warn = 'ActiveSupport::BufferedLogger is deprecated! Use ActiveSupport::Logger instead.'

    ActiveSupport::Deprecation.expects(:warn).with(warn).once

    Class.new(ActiveSupport::BufferedLogger)
  end

  def test_issues_deprecation_when_instantiated
    warn = 'ActiveSupport::BufferedLogger is deprecated! Use ActiveSupport::Logger instead.'

    ActiveSupport::Deprecation.expects(:warn).with(warn).once

    ActiveSupport::BufferedLogger.new(STDOUT)
  end

end
