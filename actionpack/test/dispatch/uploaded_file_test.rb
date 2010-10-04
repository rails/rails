require 'abstract_unit'

module ActionDispatch
  class UploadedFileTest < ActiveSupport::TestCase
    def test_original_filename
      uf = Http::UploadedFile.new(:filename => 'foo')
      assert_equal 'foo', uf.original_filename
    end

    def test_content_type
      uf = Http::UploadedFile.new(:type => 'foo')
      assert_equal 'foo', uf.content_type
    end

    def test_headers
      uf = Http::UploadedFile.new(:head => 'foo')
      assert_equal 'foo', uf.headers
    end

    def test_tempfile
      uf = Http::UploadedFile.new(:tempfile => 'foo')
      assert_equal 'foo', uf.tempfile
    end
  end
end
