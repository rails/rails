# frozen_string_literal: true

require "abstract_unit"
require "active_support/encrypted_file"

class EncryptedFileTest < ActiveSupport::TestCase
  setup do
    @content = "One little fox jumped over the hedge"

    @content_path = File.join(Dir.tmpdir, "content.txt.enc")

    @key_path = File.join(Dir.tmpdir, "content.txt.key")
    File.write(@key_path, ActiveSupport::EncryptedFile.generate_key)

    @encrypted_file = ActiveSupport::EncryptedFile.new(
      content_path: @content_path, key_path: @key_path, env_key: "CONTENT_KEY", raise_if_missing_key: true
    )
  end

  teardown do
    FileUtils.rm_rf @content_path
    FileUtils.rm_rf @key_path
  end

  test "reading content by env key" do
    FileUtils.rm_rf @key_path

    begin
      ENV["CONTENT_KEY"] = ActiveSupport::EncryptedFile.generate_key
      @encrypted_file.write @content

      assert_equal @content, @encrypted_file.read
    ensure
      ENV["CONTENT_KEY"] = nil
    end
  end

  test "reading content by key file" do
    @encrypted_file.write(@content)
    assert_equal @content, @encrypted_file.read
  end

  test "change content by key file" do
    @encrypted_file.write(@content)
    @encrypted_file.change do |file|
      file.write(file.read + " and went by the lake")
    end

    assert_equal "#{@content} and went by the lake", @encrypted_file.read
  end

  test "raise MissingKeyError when key is missing" do
    assert_raise(ActiveSupport::EncryptedFile::MissingKeyError) do
      ActiveSupport::EncryptedFile.new(
        content_path: @content_path, key_path: "", env_key: "", raise_if_missing_key: true
      ).read
    end
  end
end
