require 'helper'
require 'jobs/rescue_job'

require 'active_support/core_ext/object/inclusion'

class RescueTest < ActiveSupport::TestCase
  setup do
    $BUFFER = []
  end

  test 'rescue perform exception with retry' do
    job = RescueJob.new
    job.execute(SecureRandom.uuid, "david")
    assert_equal [ "rescued from ArgumentError", "performed beautifully" ], $BUFFER
  end

  test 'let through unhandled perform exception' do
    job = RescueJob.new
    assert_raises(RescueJob::OtherError) do
      job.execute(SecureRandom.uuid, "other")
    end
  end
end
