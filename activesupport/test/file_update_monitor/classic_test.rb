require 'abstract_unit'
require 'file_update_monitor_shared_tests'

class ClassicFileUpdateMonitorTest < ActiveSupport::TestCase
  include FileUpdateMonitorSharedTests

  def new_checker(files = [], dirs = {}, &block)
    ActiveSupport::FileUpdateMonitor::Classic.new(files, dirs, &block)
  end

  def wait
    # noop
  end

  def touch(files)
    sleep 1 # let's wait a bit to ensure there's a new mtime
    super
  end
end
