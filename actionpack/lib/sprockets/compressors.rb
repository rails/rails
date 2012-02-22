module Sprockets
  module Compressors
    extend self

    @@css_compressors = {}
    @@js_compressors = {}
    @@default_css_compressor = nil
    @@default_js_compressor = nil

    def register_css_compressor(name, klass, options = {})
      @@default_css_compressor = name.to_sym if options[:default] || @@default_css_compressor.nil?
      @@css_compressors[name.to_sym] = { :klass => klass.to_s, :require => options[:require] }
    end

    def register_js_compressor(name, klass, options = {})
      @@default_js_compressor = name.to_sym if options[:default] || @@default_js_compressor.nil?
      @@js_compressors[name.to_sym] = { :klass => klass.to_s, :require => options[:require] }
    end

    def registered_css_compressor(name)
      find_registered_compressor name, @@css_compressors, @@default_css_compressor
    end

    def registered_js_compressor(name)
      find_registered_compressor name, @@js_compressors, @@default_js_compressor
    end

    # The default compressors must be registered in default plugins (ex. Sass-Rails)
    register_css_compressor(:scss, 'Sass::Rails::Compressor', :require => 'sass/rails/compressor', :default => true)
    register_js_compressor(:uglifier, 'Uglifier', :require => 'uglifier', :default => true)

    # Automaticaly register some compressors
    register_css_compressor(:yui, 'YUI::CssCompressor', :require => 'yui/compressor')
    register_js_compressor(:closure, 'Closure::Compiler', :require => 'closure-compiler')
    register_js_compressor(:yui, 'YUI::JavaScriptCompressor', :require => 'yui/compressor')

    private

    def find_registered_compressor(name, compressors_hash, default_compressor_name)
      if name.respond_to?(:to_sym)
        compressor = compressors_hash[name.to_sym] || compressors_hash[default_compressor_name]
        require compressor[:require] if compressor[:require]
        compressor[:klass].constantize.new
      else
        name
      end
    end
  end

  # An asset compressor which does nothing.
  #
  # This compressor simply returns the asset as-is, without any compression
  # whatsoever. It is useful in development mode, when compression isn't
  # needed but using the same asset pipeline as production is desired.
  class NullCompressor #:nodoc:
    def compress(content)
      content
    end
  end

  # An asset compressor which only initializes the underlying compression
  # engine when needed.
  #
  # This postpones the initialization of the compressor until
  # <code>#compress</code> is called the first time.
  class LazyCompressor #:nodoc:
    # Initializes a new LazyCompressor.
    #
    # The block should return a compressor when called, i.e. an object
    # which responds to <code>#compress</code>.
    def initialize(&block)
      @block = block
    end

    def compress(content)
      compressor.compress(content)
    end

    private

    def compressor
      @compressor ||= (@block.call || NullCompressor.new)
    end
  end
end
