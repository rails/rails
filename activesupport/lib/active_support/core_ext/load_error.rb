class LoadError
  REGEXPS = [
    /^no such file to load -- (.+)$/i,
    /^Missing \w+ (?:file\s*)?([^\s]+.rb)$/i,
    /^Missing API definition file in (.+)$/i,
    /^cannot load such file -- (.+)$/i,
  ]

  # Returns true if the given path name (except perhaps for the ".rb"
  # extension) is the missing file which caused the exception to be raised.
  def is_missing?(location)
    location.sub(/\.rb$/, "".freeze) == path.sub(/\.rb$/, "".freeze)
  end
end
