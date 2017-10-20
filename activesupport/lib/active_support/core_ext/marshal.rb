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
        source.rewind if source.respond_to?(:rewind)
        retry
      else
        raise exc
      end
    end
  end
end

Marshal.singleton_class.prepend(ActiveSupport::MarshalWithAutoloading)
