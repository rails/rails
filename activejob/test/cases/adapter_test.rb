require 'helper'

class AdapterTest < ActiveSupport::TestCase
  test "should load #{ENV['AJADAPTER']} adapter" do
    ActiveJob::Base.queue_adapter = ENV['AJADAPTER'].to_sym
    assert_equal ActiveJob::Base.queue_adapter, "active_job/queue_adapters/#{ENV['AJADAPTER']}_adapter".classify.constantize
  end
end
