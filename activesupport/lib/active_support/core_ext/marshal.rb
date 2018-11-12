# frozen_string_literal: true

module ActiveSupport
  module MarshalWithAutoloading # :nodoc:
    def load(source, proc = nil)
      super(source, proc)
    rescue ArgumentError, NameError => exc
      if exc.message.match(%r|undefined class/module (.+?)(?:::)?\z|)
        # try loading the class/module
        loaded = $1.constantize

        raise unless $1 == loaded.name

        # if it is an IO we need to go back to read the object
        begin
          source.rewind if source.respond_to?(:rewind)
          retry
        rescue
          # Raises original error for source that cannot be rewound
          # such as pipe passed to Marshal.load
          raise exc
        end
      else
        raise exc
      end
    end
  end
end

Marshal.singleton_class.prepend(ActiveSupport::MarshalWithAutoloading)
