require "test_helper"
require "database/setup"
require "active_vault/blob"

# ActiveRecord::Base.logger = Logger.new(STDOUT)

class User < ActiveRecord::Base
  has_file :avatar
end

class ActiveVault::AttachmentsTest < ActiveSupport::TestCase
  setup { @user = User.create!(name: "DHH") }

  test "create attachment from existing blob" do
    @user.avatar = create_blob filename: "funky.jpg"
    assert_equal "funky.jpg", @user.avatar.filename.to_s
  end

  test "purge attached blob" do
    @user.avatar = create_blob filename: "funky.jpg"
    avatar_key = @user.avatar.key

    @user.avatar.purge
    assert_nil @user.avatar
    assert_not ActiveVault::Blob.site.exist?(avatar_key)
  end
end
