class LoadError
  REGEXPS = [
    /^no such file to load -- (.+)$/i,
    /^Missing \w+ (?:file\s*)?([^\s]+.rb)$/i,
    /^Missing API definition file in (.+)$/i,
    /^cannot load such file -- (.+)$/i,
  ]

  unless method_defined?(:path)
    def path
      path_from_message
    end
  end

  def is_missing?(location)
    file_path = (path || path_from_message).to_s
    location.sub(/\.rb$/, '') == file_path.sub(/\.rb$/, '')
  end

  private

  def path_from_message
    @path_from_message ||= begin
      REGEXPS.find do |regex|
        message =~ regex
      end
      $1
    end
  end
end

MissingSourceFile = LoadError
