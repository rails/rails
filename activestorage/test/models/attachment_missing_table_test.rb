# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::AttachmentMissingTableTest < ActiveSupport::TestCase
  setup do
    ActiveRecord::Migrator.down File.expand_path("../../db/migrate", __dir__)
    ActiveRecord::Base.clear_cache!
    @user = User.create!(name: "DHH")
  end

  teardown do
    ActiveRecord::Migrator.migrate File.expand_path("../../db/migrate", __dir__)
    ActiveRecord::Base.clear_cache!
  end

  test "attach a blob when Active Storage tables have not been setup" do
    assert_raise ActiveStorage::Attached::MissingTableError do
      @user.avatar.attach io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpg"
    end
  end

  test "attach many blobs when Active Storage tables have not been setup" do
    assert_raise ActiveStorage::Attached::MissingTableError do
      @user.highlights.attach(
        { io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpg" },
        { io: StringIO.new("IT"), filename: "country.jpg", content_type: "image/jpg" }
      )
    end
  end
end
