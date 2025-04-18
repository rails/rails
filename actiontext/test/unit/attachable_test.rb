# frozen_string_literal: true

require "test_helper"

class ActionText::AttachableTest < ActiveSupport::TestCase
  test "as_json is a hash when the attachable is persisted" do
    freeze_time do
      attachable = ActiveStorage::Blob.create_after_unfurling!(io: StringIO.new("test"), filename: "test.txt", key: 123)
      attributes = {
        id: attachable.id,
        key: "123",
        filename: "test.txt",
        content_type: "text/plain",
        metadata: { identified: true },
        service_name: "test",
        byte_size: 4,
        checksum: "CY9rzUYh03PK3k6DJie09g==",
        created_at: Time.zone.now.as_json,
        attachable_sgid: attachable.attachable_sgid
      }.deep_stringify_keys

      assert_equal attributes, attachable.as_json
    end
  end

  test "as_json is a hash when the attachable is a new record" do
    attachable = ActiveStorage::Blob.build_after_unfurling(io: StringIO.new("test"), filename: "test.txt", key: 123)
    attributes = {
      id: nil,
      key: "123",
      filename: "test.txt",
      content_type: "text/plain",
      metadata: { identified: true },
      service_name: "test",
      byte_size: 4,
      checksum: "CY9rzUYh03PK3k6DJie09g==",
      created_at: nil,
      attachable_sgid: nil
    }.deep_stringify_keys

    assert_equal attributes, attachable.as_json
  end

  test "attachable_sgid is included in as_json when only option is nil or includes attachable_sgid" do
    attachable = ActiveStorage::Blob.create_after_unfurling!(io: StringIO.new("test"), filename: "test.txt", key: 123)

    assert_equal({ "id" => attachable.id }, attachable.as_json(only: :id))
    assert_equal({ "id" => attachable.id }, attachable.as_json(only: [:id]))
    assert_equal(attachable.as_json.except("attachable_sgid"), attachable.as_json(except: :attachable_sgid))
    assert_equal(attachable.as_json.except("attachable_sgid"), attachable.as_json(except: [:attachable_sgid]))
  end
end
