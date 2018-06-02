# frozen_string_literal: true

require "abstract_unit"

module ActionDispatch
  class UploadedFileTest < ActiveSupport::TestCase
    def test_constructor_with_argument_error
      assert_raises(ArgumentError) do
        Http::UploadedFile.new({})
      end
    end

    def test_original_filename
      uf = Http::UploadedFile.new(filename: "foo", tempfile: Object.new)
      assert_equal "foo", uf.original_filename
    end

    def test_filename_is_different_object
      file_str = "foo"
      uf = Http::UploadedFile.new(filename: file_str, tempfile: Object.new)
      assert_not_equal file_str.object_id, uf.original_filename.object_id
    end

    def test_filename_should_be_in_utf_8
      uf = Http::UploadedFile.new(filename: "foo", tempfile: Object.new)
      assert_equal "UTF-8", uf.original_filename.encoding.to_s
    end

    def test_filename_should_always_be_in_utf_8
      uf = Http::UploadedFile.new(filename: "foo".encode(Encoding::SHIFT_JIS),
                                  tempfile: Object.new)
      assert_equal "UTF-8", uf.original_filename.encoding.to_s
    end

    def test_content_type
      uf = Http::UploadedFile.new(type: "foo", tempfile: Object.new)
      assert_equal "foo", uf.content_type
    end

    def test_headers
      uf = Http::UploadedFile.new(head: "foo", tempfile: Object.new)
      assert_equal "foo", uf.headers
    end

    def test_tempfile
      uf = Http::UploadedFile.new(tempfile: "foo")
      assert_equal "foo", uf.tempfile
    end

    def test_to_io_returns_the_tempfile
      tf = Object.new
      uf = Http::UploadedFile.new(tempfile: tf)
      assert_equal tf, uf.to_io
    end

    def test_delegates_path_to_tempfile
      tf = Class.new { def path; "thunderhorse" end }
      uf = Http::UploadedFile.new(tempfile: tf.new)
      assert_equal "thunderhorse", uf.path
    end

    def test_delegates_open_to_tempfile
      tf = Class.new { def open; "thunderhorse" end }
      uf = Http::UploadedFile.new(tempfile: tf.new)
      assert_equal "thunderhorse", uf.open
    end

    def test_delegates_close_to_tempfile
      tf = Class.new { def close(unlink_now = false); "thunderhorse" end }
      uf = Http::UploadedFile.new(tempfile: tf.new)
      assert_equal "thunderhorse", uf.close
    end

    def test_close_accepts_parameter
      tf = Class.new { def close(unlink_now = false); "thunderhorse: #{unlink_now}" end }
      uf = Http::UploadedFile.new(tempfile: tf.new)
      assert_equal "thunderhorse: true", uf.close(true)
    end

    def test_delegates_read_to_tempfile
      tf = Class.new { def read(length = nil, buffer = nil); "thunderhorse" end }
      uf = Http::UploadedFile.new(tempfile: tf.new)
      assert_equal "thunderhorse", uf.read
    end

    def test_delegates_read_to_tempfile_with_params
      tf = Class.new { def read(length = nil, buffer = nil); [length, buffer] end }
      uf = Http::UploadedFile.new(tempfile: tf.new)
      assert_equal %w{ thunder horse }, uf.read(*%w{ thunder horse })
    end

    def test_delegate_respects_respond_to?
      tf = Class.new { def read; yield end; private :read }
      uf = Http::UploadedFile.new(tempfile: tf.new)
      assert_raises(NoMethodError) do
        uf.read
      end
    end

    def test_delegate_eof_to_tempfile
      tf = Class.new { def eof?; true end; }
      uf = Http::UploadedFile.new(tempfile: tf.new)
      assert_predicate uf, :eof?
    end

    def test_respond_to?
      tf = Class.new { def read; yield end }
      uf = Http::UploadedFile.new(tempfile: tf.new)
      assert_respond_to uf, :headers
      assert_respond_to uf, :read
    end
  end
end
