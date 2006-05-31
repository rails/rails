class MissingSourceFile < LoadError #:nodoc:
  attr_reader :path
  def initialize(message, path)
    super(message)
    @path = path
  end

  def is_missing?(path)
    path.gsub(/\.rb$/, '') == self.path.gsub(/\.rb$/, '')
  end

  def self.from_message(message)
    REGEXPS.each do |regexp, capture|
      match = regexp.match(message)
      return MissingSourceFile.new(message, match[capture]) unless match.nil?
    end
    nil
  end

  REGEXPS = [
    [/^no such file to load -- (.+)$/i, 1],
    [/^Missing \w+ (file\s*)?([^\s]+.rb)$/i, 2],
    [/^Missing API definition file in (.+)$/i, 1]
  ] unless defined?(REGEXPS)
end

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module LoadErrorExtensions #:nodoc:
      module LoadErrorClassMethods #:nodoc:
        def new(*args)
          (self == LoadError && MissingSourceFile.from_message(args.first)) || super
        end
      end
      ::LoadError.extend(LoadErrorClassMethods)
    end
  end
end
