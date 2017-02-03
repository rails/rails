require "cases/helper"
require "models/notification"
require "models/user"

class SuppressorTest < ActiveRecord::TestCase
  def test_suppresses_create
    assert_no_difference -> { Notification.count } do
      Notification.suppress do
        Notification.create
        Notification.create!
        Notification.new.save
        Notification.new.save!
      end
    end
  end

  def test_suppresses_update
    user = User.create! token: "asdf"

    User.suppress do
      user.update token: "ghjkl"
      assert_equal "asdf", user.reload.token

      user.update! token: "zxcvbnm"
      assert_equal "asdf", user.reload.token

      user.token = "qwerty"
      user.save
      assert_equal "asdf", user.reload.token

      user.token = "uiop"
      user.save!
      assert_equal "asdf", user.reload.token
    end
  end

  def test_suppresses_create_in_callback
    assert_difference -> { User.count } do
      assert_no_difference -> { Notification.count } do
        Notification.suppress { UserWithNotification.create! }
      end
    end
  end

  def test_resumes_saving_after_suppression_complete
    Notification.suppress { UserWithNotification.create! }

    assert_difference -> { Notification.count } do
      Notification.create!(message: "New Comment")
    end
  end

  def test_suppresses_validations_on_create
    assert_no_difference -> { Notification.count } do
      Notification.suppress do
        User.create
        User.create!
        User.new.save
        User.new.save!
      end
    end
  end

  def test_suppresses_when_nested_multiple_times
    assert_no_difference -> { Notification.count } do
      Notification.suppress do
        Notification.suppress {}
        Notification.create
        Notification.create!
        Notification.new.save
        Notification.new.save!
      end
    end
  end
end
