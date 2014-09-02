require 'helper'
require 'jobs/rescue_job'
require 'models/person'

require 'active_support/core_ext/object/inclusion'

class RescueTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
  end

  test 'rescue perform exception with retry' do
    job = RescueJob.new
    job.execute(SecureRandom.uuid, "david")
    assert_equal [ "rescued from ArgumentError", "performed beautifully" ], JobBuffer.values
  end

  test 'let through unhandled perform exception' do
    job = RescueJob.new
    assert_raises(RescueJob::OtherError) do
      job.execute(SecureRandom.uuid, "other")
    end
  end

  test 'rescue from deserialization errors' do
    RescueJob.enqueue Person.new(404)
    assert_includes JobBuffer.values, 'rescued from DeserializationError'
    assert_includes JobBuffer.values, 'DeserializationError original exception was Person::RecordNotFound'
    assert_not_includes JobBuffer.values, 'performed beautifully'
  end
end
