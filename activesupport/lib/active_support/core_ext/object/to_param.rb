class Object
  # Alias of <tt>to_s</tt>.
  def to_param
    to_s
  end
end

class NilClass
  # Returns +self+.
  def to_param
    self
  end
end

class TrueClass
  # Returns +self+.
  def to_param
    self
  end
end

class FalseClass
  # Returns +self+.
  def to_param
    self
  end
end

class Array
  # Calls <tt>to_param</tt> on all its elements and joins the result with
  # slashes. This is used by <tt>url_for</tt> in Action Pack.
  def to_param
    collect { |e| e.to_param }.join '/'
  end
end

class Hash
  # Returns a string representation of the receiver suitable for use as a URL
  # query string:
  #
  #   {name: 'David', nationality: 'Danish'}.to_param
  #   # => "name=David&nationality=Danish"
  #
  # An optional namespace can be passed to enclose the param names:
  #
  #   {name: 'David', nationality: 'Danish'}.to_param('user')
  #   # => "user[name]=David&user[nationality]=Danish"
  #
  # The string pairs "key=value" that conform the query string
  # are sorted lexicographically in ascending order.
  #
  # This method is also aliased as +to_query+.
  def to_param(namespace = nil)
    collect do |key, value|
      value.to_query(namespace ? "#{namespace}[#{key}]" : key)
    end.sort * '&'
  end
end
