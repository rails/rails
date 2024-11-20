# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/core_ext/object/with"
require "active_support/encrypted_file"

class EncryptedFileTest < ActiveSupport::TestCase
  setup do
    @original_env_content_key = ENV["CONTENT_KEY"]
    ENV["CONTENT_KEY"] = nil

    @content = "One little fox jumped over the hedge"

    @tmpdir = Dir.mktmpdir("encrypted-file-test-")
    @content_path = File.join(@tmpdir, "content.txt.enc")

    @key = ActiveSupport::EncryptedFile.generate_key
    @key_path = File.join(@tmpdir, "content.txt.key")
    File.write(@key_path, @key)

    @encrypted_file = encrypted_file(@content_path)
  end

  teardown do
    FileUtils.rm_rf @content_path
    FileUtils.rm_rf @key_path
    FileUtils.rm_rf @tmpdir

    ENV["CONTENT_KEY"] = @original_env_content_key
  end

  test "reading content by env key" do
    FileUtils.rm_rf @key_path

    ENV["CONTENT_KEY"] = @key
    @encrypted_file.write @content

    assert_equal @content, @encrypted_file.read
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

  test "change sets restricted permissions" do
    @encrypted_file.write(@content)
    @encrypted_file.change do |file|
      assert_predicate file, :owned?
      assert_equal "100600", file.stat.mode.to_s(8), "Incorrect mode for #{file}"
    end
  end

  test "raise MissingKeyError when key is missing" do
    assert_raise ActiveSupport::EncryptedFile::MissingKeyError do
      encrypted_file(@content_path, key_path: "", env_key: "").read
    end
  end

  test "raise MissingKeyError when env key is blank" do
    FileUtils.rm_rf @key_path

    ENV["CONTENT_KEY"] = ""
    raised = assert_raise ActiveSupport::EncryptedFile::MissingKeyError do
      @encrypted_file.write @content
      @encrypted_file.read
    end

    assert_match(/Missing encryption key to decrypt file/, raised.message)
  end

  test "key can be added after MissingKeyError raised" do
    FileUtils.rm_rf @key_path

    assert_raise ActiveSupport::EncryptedFile::MissingKeyError do
      @encrypted_file.key
    end

    File.write(@key_path, @key)

    assert_nothing_raised do
      assert_equal @key, @encrypted_file.key
    end
  end

  test "key? is true when key file exists" do
    assert_predicate @encrypted_file, :key?
  end

  test "key? is true when env key is present" do
    FileUtils.rm_rf @key_path
    ENV["CONTENT_KEY"] = @key

    assert_predicate @encrypted_file, :key?
  end

  test "key? is false and does not raise when the key is missing" do
    FileUtils.rm_rf @key_path

    assert_nothing_raised do
      assert_not @encrypted_file.key?
    end
  end

  test "raise InvalidKeyLengthError when key is too short" do
    File.write(@key_path, ActiveSupport::EncryptedFile.generate_key[0..-2])

    assert_raise ActiveSupport::EncryptedFile::InvalidKeyLengthError do
      @encrypted_file.write(@content)
    end
  end

  test "raise InvalidKeyLengthError when key is too long" do
    File.write(@key_path, ActiveSupport::EncryptedFile.generate_key + "0")

    assert_raise ActiveSupport::EncryptedFile::InvalidKeyLengthError do
      @encrypted_file.write(@content)
    end
  end

  test "respects existing content_path symlink" do
    @encrypted_file.write(@content)

    symlink_path = File.join(@tmpdir, "content_symlink.txt.enc")
    File.symlink(@encrypted_file.content_path, symlink_path)

    encrypted_file(symlink_path).write(@content)

    assert File.symlink?(symlink_path)
    assert_equal @content, @encrypted_file.read
  ensure
    FileUtils.rm_rf symlink_path
  end

  test "creates new content_path symlink if it's dead" do
    symlink_path = File.join(@tmpdir, "content_symlink.txt.enc")
    File.symlink(@content_path, symlink_path)

    encrypted_file(symlink_path).write(@content)

    assert File.exist?(@content_path)
    assert_equal @content, @encrypted_file.read
  ensure
    FileUtils.rm_rf symlink_path
  end

  test "can read encrypted file after changing default_serializer" do
    ActiveSupport::Messages::Codec.with(default_serializer: :marshal) do
      encrypted_file(@content_path).write(@content)
    end

    ActiveSupport::Messages::Codec.with(default_serializer: :json) do
      assert_equal @content, encrypted_file(@content_path).read
    end
  end

  private
    def encrypted_file(content_path, key_path: @key_path, env_key: "CONTENT_KEY")
      ActiveSupport::EncryptedFile.new(content_path: @content_path, key_path: key_path,
        env_key: env_key, raise_if_missing_key: true)
    end
end
