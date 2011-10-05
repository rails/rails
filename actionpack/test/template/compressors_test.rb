require 'abstract_unit'
require 'sprockets/compressors'

class CompressorsTest < ActiveSupport::TestCase
  def test_register_css_compressor
    Sprockets::Compressors.register_css_compressor(:null, Sprockets::NullCompressor)
    compressor = Sprockets::Compressors.registered_css_compressor(:null)
    assert_kind_of Sprockets::NullCompressor, compressor
  end

  def test_register_js_compressor
    Sprockets::Compressors.register_js_compressor(:uglifier, 'Uglifier', :require => 'uglifier')
    compressor = Sprockets::Compressors.registered_js_compressor(:uglifier)
    assert_kind_of Uglifier, compressor
  end

  def test_register_default_css_compressor
    Sprockets::Compressors.register_css_compressor(:null, Sprockets::NullCompressor, :default => true)
    compressor = Sprockets::Compressors.registered_css_compressor(:default)
    assert_kind_of Sprockets::NullCompressor, compressor
  end

  def test_register_default_js_compressor
    Sprockets::Compressors.register_js_compressor(:null, Sprockets::NullCompressor, :default => true)
    compressor = Sprockets::Compressors.registered_js_compressor(:default)
    assert_kind_of Sprockets::NullCompressor, compressor
  end
end
