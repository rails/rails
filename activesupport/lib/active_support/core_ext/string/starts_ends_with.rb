class String
  unless '1.8.7 and up'.respond_to?(:start_with?)
    # Does the string start with the specified +prefix+?
    def start_with?(prefix)
      prefix = prefix.to_s
      self[0, prefix.length] == prefix
    end

    # Does the string end with the specified +suffix+?
    def end_with?(suffix)
      suffix = suffix.to_s
      self[-suffix.length, suffix.length] == suffix
    end
  end

  alias_method :starts_with?, :start_with?
  alias_method :ends_with?, :end_with?
end
