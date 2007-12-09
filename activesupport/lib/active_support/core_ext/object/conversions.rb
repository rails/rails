class Object
  # Alias of <tt>to_s</tt>.
  def to_param
    to_s
  end

  # Converts an object into a string suitable for use as a URL query string, using the given <tt>key</tt> as the
  # param name.
  #
  # Note: This method is defined as a default implementation for all Objects for Hash#to_query to work.
  def to_query(key)
    "#{CGI.escape(key.to_s)}=#{CGI.escape(to_param.to_s)}"
  end
end