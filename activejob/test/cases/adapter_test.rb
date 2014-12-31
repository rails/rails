require 'helper'

class AdapterTest < ActiveSupport::TestCase
  test "should load #{ENV['AJADAPTER']} adapter" do
    assert_equal "active_job/queue_adapters/#{ENV['AJADAPTER']}_adapter".classify, ActiveJob::Base.queue_adapter.name
  end
end
