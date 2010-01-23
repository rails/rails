require 'abstract_controller/collector'

module ActionMailer #:nodoc:

  class Collector
  
    include AbstractController::Collector
  
    attr_accessor :responses

    def initialize(context, options, &block)
      @default_options = options
      @default_render = block
      @default_formats = context.formats
      @context = context
      @responses = []
    end

    def custom(mime, options={}, &block)
      options = @default_options.merge(:content_type => mime.to_s).merge(options)
      @context.formats = [mime.to_sym]
      options[:body] = if block
        block.call
      else
        @default_render.call
      end
      @responses << options
      @context.formats = @default_formats
    end

  end
end