# frozen_string_literal: true

require "action_view/template"

module ActionView
  class FileTemplate < Template
    def initialize(filename, handler, details)
      @filename = filename

      super(nil, filename, handler, details)
    end

    def source
      File.binread @filename
    end

    def refresh(_)
      self
    end

    # Exceptions are marshalled when using the parallel test runner with DRb, so we need
    # to ensure that references to the template object can be marshalled as well. This means forgoing
    # the marshalling of the compiler mutex and instantiating that again on unmarshalling.
    def marshal_dump # :nodoc:
      [ @identifier, @handler, @compiled, @original_encoding, @locals, @virtual_path, @updated_at, @formats, @variants ]
    end

    def marshal_load(array) # :nodoc:
      @identifier, @handler, @compiled, @original_encoding, @locals, @virtual_path, @updated_at, @formats, @variants = *array
      @compile_mutex = Mutex.new
    end
  end
end
