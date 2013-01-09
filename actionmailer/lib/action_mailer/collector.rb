require 'abstract_controller/collector'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/core_ext/array/extract_options'

module ActionMailer
  class Collector
    include AbstractController::Collector
    attr_reader :responses

    def initialize(context, &block)
      @context = context
      @responses = []
      @default_render = block
    end

    def any(*args, &block)
      options = args.extract_options!
      raise ArgumentError, "You have to supply at least one format" if args.empty?
      args.each { |type| send(type, options.dup, &block) }
    end
    alias :all :any

    def custom(mime, options = {})
      options.reverse_merge!(content_type: mime.to_s)
      @context.formats = [mime.to_sym]
      options[:body] = block_given? ? yield : @default_render.call
      @responses << options
    end
  end
end
