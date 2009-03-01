module ActiveSupport
  class << self
    def core_ext(subject, names)
      names.each do |name|
        require "active_support/core_ext/#{Inflector.underscore(subject.name)}/#{name}"
        subject.send :include, Inflector.constantize("ActiveSupport::CoreExtensions::#{subject.name}::#{Inflector.camelize(name)}")
      end
    end
  end
end
