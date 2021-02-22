# frozen_string_literal: true

require "abstract_unit"
require "tempfile"
require "stringio"

module ActionDispatch
  class UploadedFileTest < ActiveSupport::TestCase
    def test_constructor_with_argument_error
      assert_raises(ArgumentError) do
        Http::UploadedFile.new({})
      end
    end

    def test_original_filename
      uf = Http::UploadedFile.new(filename: "foo", tempfile: Tempfile.new)
      assert_equal "foo", uf.original_filename
    end

    def test_filename_is_different_object
      file_str = "foo"
      uf = Http::UploadedFile.new(filename: file_str, tempfile: Tempfile.new)
      assert_not_equal file_str.object_id, uf.original_filename.object_id
    end

    def test_filename_should_be_in_utf_8
      uf = Http::UploadedFile.new(filename: "foo", tempfile: Tempfile.new)
      assert_equal "UTF-8", uf.original_filename.encoding.to_s
    end

    def test_filename_should_always_be_in_utf_8
      uf = Http::UploadedFile.new(filename: "foo".encode(Encoding::SHIFT_JIS),
                                  tempfile: Tempfile.new)
      assert_equal "UTF-8", uf.original_filename.encoding.to_s
    end

    def test_content_type
      uf = Http::UploadedFile.new(type: "foo", tempfile: Tempfile.new)
      assert_equal "foo", uf.content_type
    end

    def test_headers
      uf = Http::UploadedFile.new(head: "foo", tempfile: Tempfile.new)
      assert_equal "foo", uf.headers
    end

    def test_headers_should_be_in_utf_8
      uf = Http::UploadedFile.new(filename: "foo", head: "foo", tempfile: Tempfile.new)
      assert_equal "UTF-8", uf.headers.encoding.to_s
    end

    def test_headers_should_always_be_in_utf_8
      uf = Http::UploadedFile.new(filename: "foo",
                                  head: "\xC3foo".dup.force_encoding(Encoding::ASCII_8BIT),
                                  tempfile: Tempfile.new)
      assert_equal "UTF-8", uf.headers.encoding.to_s
    end

    def test_tempfile
      tf = Tempfile.new
      uf = Http::UploadedFile.new(tempfile: tf)
      assert_equal tf, uf.tempfile
    end

    def test_to_io_returns_file
      tf = Tempfile.new
      uf = Http::UploadedFile.new(tempfile: tf)
      assert_equal tf.to_io, uf.to_io
    end

    def test_delegates_path_to_tempfile
      tf = Tempfile.new
      uf = Http::UploadedFile.new(tempfile: tf)
      assert_equal tf.path, uf.path
    end

    def test_delegates_open_to_tempfile
      tf = Tempfile.new
      tf.close
      uf = Http::UploadedFile.new(tempfile: tf)
      assert_equal tf, uf.open
      assert_not tf.closed?
    end

    def test_delegates_close_to_tempfile
      tf = Tempfile.new
      uf = Http::UploadedFile.new(tempfile: tf)
      uf.close
      assert tf.closed?
    end

    def test_close_accepts_parameter
      tf = Tempfile.new
      uf = Http::UploadedFile.new(tempfile: tf)
      uf.close(true)
      assert tf.closed?
      assert_nil tf.path
    end

    def test_delegates_read_to_tempfile
      tf = Tempfile.new
      tf << "thunderhorse"
      tf.rewind
      uf = Http::UploadedFile.new(tempfile: tf)
      assert_equal "thunderhorse", uf.read
    end

    def test_delegates_read_to_tempfile_with_params
      tf = Tempfile.new
      tf << "thunderhorse"
      tf.rewind
      uf = Http::UploadedFile.new(tempfile: tf)
      assert_equal "thunder", uf.read(7)
      assert_equal "horse",   uf.read(5, String.new)
    end

    def test_delegate_eof_to_tempfile
      tf = Tempfile.new
      tf << "thunderhorse"
      uf = Http::UploadedFile.new(tempfile: tf)
      assert_equal true, uf.eof?
      tf.rewind
      assert_equal false, uf.eof?
    end

    def test_delegate_to_path_to_tempfile
      tf = Tempfile.new
      uf = Http::UploadedFile.new(tempfile: tf)
      assert_equal tf.to_path, uf.to_path
    end

    def test_io_copy_stream
      tf = Tempfile.new
      tf << "thunderhorse"
      tf.rewind
      uf = Http::UploadedFile.new(tempfile: tf)
      result = StringIO.new
      IO.copy_stream(uf, result)
      assert_equal "thunderhorse", result.string
    end
  end
end
