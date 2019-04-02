# frozen_string_literal: true

require_relative "../dummy/config/environment.rb"

class ActiveStorage::TableNamePrefixSuffixTest < ActiveSupport::TestCase
  setup do
    ActiveRecord::Base.table_name_prefix = "bcx_"
    ActiveRecord::Base.table_name_suffix = "_classic"
  end

  teardown do
    ActiveRecord::Base.table_name_prefix = ""
    ActiveRecord::Base.table_name_suffix = ""
  end

  test "table name prefix and suffix are added to the active storage tables properly" do
    assert_equal "bcx_active_storage_blobs_classic", ActiveStorage::Blob.table_name
    assert_equal "bcx_active_storage_attachments_classic", ActiveStorage::Attachment.table_name
  end
end
