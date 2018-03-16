# frozen_string_literal: true

class LoadError
  # Returns true if the given path name (except perhaps for the ".rb"
  # extension) is the missing file which caused the exception to be raised.
  def is_missing?(location)
    location.sub(/\.rb$/, "") == path.sub(/\.rb$/, "")
  end
end
