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
    [/^Missing API definition file in (.+)$/i, 1],
    [/win32/, 0]
  ] unless defined?(REGEXPS)
end

class LoadError
  def self.new(*args)
    if self == LoadError
      MissingSourceFile.from_message(args.first)
    else
      super
    end
  end
end
