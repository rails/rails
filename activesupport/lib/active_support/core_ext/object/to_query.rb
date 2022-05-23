# frozen_string_literal: true

require "cgi"

class Object
  # Alias of <tt>to_s</tt>.
  def to_param
    to_s
  end

  ##
  # :method: to_query
  # :call-seq: to_query(key)
  #
  # Converts an object into a string suitable for use as a URL query string,
  # using the given <tt>key</tt> as the param name.
  def to_query(key, &escape)
    if escape
      "#{escape.(key.to_param)}=#{escape.(to_param.to_s)}"
    else
      "#{CGI.escape(key.to_param)}=#{CGI.escape(to_param.to_s)}"
    end
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
    collect(&:to_param).join "/"
  end

  ##
  # :method: to_query
  # :call-seq: to_query(key)
  #
  # Converts an array into a string suitable for use as a URL query string,
  # using the given +key+ as the param name.
  #
  #   ['Rails', 'coding'].to_query('hobbies') # => "hobbies%5B%5D=Rails&hobbies%5B%5D=coding"
  def to_query(key, &escape)
    prefix = "#{key}[]"

    if empty?
      nil.to_query(prefix, &escape)
    else
      collect { |value| value.to_query(prefix, &escape) }.join "&"
    end
  end
end

class Hash
  ##
  # :method: to_query
  # :call-seq: to_query(namespace = nil)
  #
  # Returns a string representation of the receiver suitable for use as a URL
  # query string:
  #
  #   {name: 'David', nationality: 'Danish'}.to_query
  #   # => "name=David&nationality=Danish"
  #
  # An optional namespace can be passed to enclose key names:
  #
  #   {name: 'David', nationality: 'Danish'}.to_query('user')
  #   # => "user%5Bname%5D=David&user%5Bnationality%5D=Danish"
  #
  # The string pairs "key=value" that conform the query string
  # are sorted lexicographically in ascending order.
  def to_query(namespace = nil, &escape)
    query = filter_map do |key, value|
      unless (value.is_a?(Hash) || value.is_a?(Array)) && value.empty?
        value.to_query(namespace ? "#{namespace}[#{key}]" : key, &escape)
      end
    end

    query.sort! unless namespace.to_s.include?("[]")
    query.join("&")
  end

  ##
  # :method: to_param
  # :call-seq: to_param()
  #
  # This method behaves like #to_query, but keys and values in the resulting
  # query string are not escaped.
  def to_param(namespace = nil)
    to_query(namespace, &:itself)
  end
end
