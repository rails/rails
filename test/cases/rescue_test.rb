require 'helper'
require 'jobs/rescue_job'

require 'active_support/core_ext/object/inclusion'

class RescueTest < ActiveSupport::TestCase
  setup do
    $BUFFER = []
  end
  
  test 'rescue perform exception with retry' do
    job = RescueJob.new
    job.perform_with_hooks("david")
    assert_equal [ "rescued from StandardError", "performed beautifully" ], $BUFFER
  end
end
