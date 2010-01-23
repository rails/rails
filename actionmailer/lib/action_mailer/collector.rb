require 'abstract_controller/collector'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/core_ext/array/extract_options'

module ActionMailer #:nodoc:
  class Collector
    include AbstractController::Collector
    attr_reader :responses

    def initialize(context, &block)
      @context = context
      @responses = []
      @default_render = block
      @default_formats = context.formats
    end

    def any(*args, &block)
      options = args.extract_options!
      raise "You have to supply at least one format" if args.empty?
      args.each { |type| send(type, options.dup, &block) }
    end
    alias :all :any

    def custom(mime, options={}, &block)
      options.reverse_merge!(:content_type => mime.to_s)
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