# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::BlobMissingTableTest < ActiveSupport::TestCase
  setup do
    ActiveRecord::Migrator.down File.expand_path("../../db/migrate", __dir__)
    ActiveRecord::Base.clear_cache!
  end

  teardown do
    ActiveRecord::Migrator.migrate File.expand_path("../../db/migrate", __dir__)
    ActiveRecord::Base.clear_cache!
  end

  test "creating a blob (after upload) when Active Storage tables have not been setup" do
    assert_raise ActiveStorage::Blob::MissingTableError do
      create_file_blob
    end
  end

  test "creating a blob (before direct upload) when Active Storage tables have not been setup" do
    assert_raise ActiveStorage::Blob::MissingTableError do
      data = "Hello world!"
      create_blob_before_direct_upload byte_size: data.size, checksum: Digest::MD5.base64digest(data)
    end
  end
end
