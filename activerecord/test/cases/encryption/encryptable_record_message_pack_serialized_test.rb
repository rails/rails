# frozen_string_literal: true

require "cases/encryption/helper"
require "models/author_encrypted"
require "models/book_encrypted"
require "active_record/encryption/message_pack_message_serializer"

class ActiveRecord::Encryption::EncryptableRecordMessagePackSerializedTest < ActiveRecord::EncryptionTestCase
  fixtures :encrypted_books

  test "binary data can be serialized with message pack" do
    all_bytes = (0..255).map(&:chr).join
    book = EncryptedBookWithBinaryMessagePackSerialized.create!(logo: all_bytes)
    assert_encrypted_attribute(book, :logo, all_bytes)
  end

  test "binary data can be encrypted uncompressed and serialized with message pack" do
    # Strings below 140 bytes are not compressed
    low_bytes = (0..127).map(&:chr).join
    high_bytes = (128..255).map(&:chr).join

    assert_encrypted_attribute(EncryptedBookWithBinaryMessagePackSerialized.create!(logo: low_bytes), :logo, low_bytes)
    assert_encrypted_attribute(EncryptedBookWithBinaryMessagePackSerialized.create!(logo: high_bytes), :logo, high_bytes)
  end

  test "text columns cannot be serialized with message pack" do
    assert_raises(ActiveRecord::Encryption::Errors::Encoding) do
      message_pack_serialized_text_class = Class.new(ActiveRecord::Base) do
        self.table_name = "encrypted_books"

        encrypts :name, message_serializer: ActiveRecord::Encryption::MessagePackMessageSerializer.new
      end
      message_pack_serialized_text_class.create(name: "Dune")
    end
  end

  class EncryptedBookWithBinaryMessagePackSerialized < ActiveRecord::Base
    self.table_name = "encrypted_books"

    encrypts :logo, message_serializer: ActiveRecord::Encryption::MessagePackMessageSerializer.new
  end
end
