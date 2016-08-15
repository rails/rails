require "active_support/deprecation/proxy_wrappers"

class LoadError
  REGEXPS = [
    /^no such file to load -- (.+)$/i,
    /^Missing \w+ (?:file\s*)?([^\s]+.rb)$/i,
    /^Missing API definition file in (.+)$/i,
    /^cannot load such file -- (.+)$/i,
  ]

  unless method_defined?(:path)
    # Returns the path which was unable to be loaded.
    def path
      @path ||= begin
        REGEXPS.find do |regex|
          message =~ regex
        end
        $1
      end
    end
  end

  # Returns true if the given path name (except perhaps for the ".rb"
  # extension) is the missing file which caused the exception to be raised.
  def is_missing?(location)
    location.sub(/\.rb$/, "".freeze) == path.sub(/\.rb$/, "".freeze)
  end
end

MissingSourceFile = ActiveSupport::Deprecation::DeprecatedConstantProxy.new("MissingSourceFile", "LoadError")
