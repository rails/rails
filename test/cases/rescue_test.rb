require 'helper'
require 'jobs/rescue_job'

require 'active_support/core_ext/object/inclusion'

class RescueTest < ActiveSupport::TestCase
  setup do
    $BUFFER = []
  end

  test 'rescue perform exception with retry' do
    RescueJob.enqueue("david")
    assert_equal [ "rescued from ArgumentError", "performed beautifully" ], $BUFFER
  end

  test 'let through unhandled perform exception' do
    assert_raises(RescueJob::OtherError) do
      RescueJob.enqueue("other")
    end
  end
end
