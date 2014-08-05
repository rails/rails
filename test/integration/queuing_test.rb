require 'helper'
require 'jobs/logging_job'
require 'active_support/core_ext/numeric/time'


class QueuingTest < ActiveSupport::TestCase
  setup do

  end

  test 'run queued job' do
    id = "AJ-#{SecureRandom.uuid}"
    TestJob.enqueue id
    sleep 2
    assert Dummy::Application.root.join("tmp/#{id}").exist?
  end

end
