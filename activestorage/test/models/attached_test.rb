# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::AttachmentsTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Josh")
  end

  teardown { ActiveStorage::Blob.all.each(&:purge) }

  test "overriding has_one_attached methods works" do
    # attach blob before messing with getter, which breaks `#attach`
    @user.avatar.attach create_blob(filename: "funky.jpg")

    # inherited only
    assert_equal "funky.jpg", @user.avatar.filename.to_s

    begin
      User.class_eval do
        def avatar
          super.filename.to_s.reverse
        end
      end

      # override with super
      assert_equal "funky.jpg".reverse, @user.avatar
    ensure
      User.send(:remove_method, :avatar)
    end
  end

  test "overriding has_many_attached methods works" do
    # attach blobs before messing with getter, which breaks `#attach`
    @user.highlights.attach create_blob(filename: "funky.jpg"), create_blob(filename: "wonky.jpg")

    # inherited only
    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "wonky.jpg", @user.highlights.second.filename.to_s

    begin
      User.class_eval do
        def highlights
          super.reverse
        end
      end

      # override with super
      assert_equal "wonky.jpg", @user.highlights.first.filename.to_s
      assert_equal "funky.jpg", @user.highlights.second.filename.to_s
    ensure
      User.send(:remove_method, :highlights)
    end
  end
end
