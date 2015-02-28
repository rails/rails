require 'cases/helper'
require 'models/notification'
require 'models/user'

class SuppressorTest < ActiveRecord::TestCase
  def test_suppresses_creation_of_record_generated_by_callback
    assert_difference -> { User.count } do
      assert_no_difference -> { Notification.count } do
        Notification.suppress { UserWithNotification.create! }
      end
    end
  end

  def test_resumes_saving_after_suppression_complete
    Notification.suppress { UserWithNotification.create! }

    assert_difference -> { Notification.count } do
      Notification.create!
    end
  end
end
