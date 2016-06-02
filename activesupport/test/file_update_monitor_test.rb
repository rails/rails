require 'abstract_unit'

class FileUpdateMonitorTest < ActiveSupport::TestCase
  def test_deprecated_file_update_checker
    assert_deprecated('ActiveSupport::FileUpdateChecker') do
      assert_equal ActiveSupport::FileUpdateChecker, ActiveSupport::FileUpdateMonitor::Classic
    end
  end

  def test_deprecated_evented_file_update_checker
    assert_deprecated('ActiveSupport::EventedFileUpdateChecker') do
      assert_equal ActiveSupport::EventedFileUpdateChecker, ActiveSupport::FileUpdateMonitor::Evented
    end
  end

  class BaseTest < ActiveSupport::TestCase
    TestMonitor1 = Class.new(ActiveSupport::FileUpdateMonitor::Base)
    TestMonitor2 = Class.new(ActiveSupport::FileUpdateMonitor::Base) do
      def initialize(*)
      end
    end

    def test_initialize_not_implemented_error
      assert_raises(NotImplementedError) do
        TestMonitor1.new('', {})
      end
    end

    def test_execute_not_implemented_error
      assert_raises(NotImplementedError) do
        TestMonitor2.new('', {}).execute
      end
    end

    def test_execute_if_updated_not_implemented_error
      assert_raises(NotImplementedError) do
        TestMonitor2.new('', {}).execute_if_updated
      end
    end

    def test_updated_not_implemented_error
      assert_raises(NotImplementedError) do
        TestMonitor2.new('', {}).updated?
      end
    end
  end
end
