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

    def test_delegates_to_tempfile
      tf = Class.new { def tenderlove; 'thunderhorse' end }
      uf = Http::UploadedFile.new(:tempfile => tf.new)
      assert_equal 'thunderhorse', uf.tenderlove
    end

    def test_delegates_to_tempfile_with_params
      tf = Class.new { def tenderlove *args; args end }
      uf = Http::UploadedFile.new(:tempfile => tf.new)
      assert_equal %w{ thunder horse }, uf.tenderlove(*%w{ thunder horse })
    end

    def test_delegates_to_tempfile_with_block
      tf = Class.new { def tenderlove; yield end }
      uf = Http::UploadedFile.new(:tempfile => tf.new)
      assert_equal('thunderhorse', uf.tenderlove { 'thunderhorse' })
    end
  end
end
