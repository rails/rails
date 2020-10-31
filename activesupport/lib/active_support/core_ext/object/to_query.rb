# frozen_string_literal: true

require "cgi"

class Object
  # Alias of <tt>to_s</tt>.
  def to_param
    to_s
  end

  # Converts an object into a string suitable for use as a URL query string,
  # using the given <tt>key</tt> as the param name.
  def to_query(key)
    "#{CGI.escape(key.to_param)}=#{CGI.escape(to_param.to_s)}"
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

  # Converts an array into a string suitable for use as a URL query string,
  # using the given +key+ as the param name.
  #
  #   ['Rails', 'coding'].to_query('hobbies') # => "hobbies%5B%5D=Rails&hobbies%5B%5D=coding"
  def to_query(key)
    prefix = "#{key}[]"

    if empty?
      nil.to_query(prefix)
    else
      collect { |value| value.to_query(prefix) }.join "&"
    end
  end
end

class Hash
  @@valid_options_for_to_query = Set[:namespace, :preserve_order].freeze

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
  # An options hash can be passed in place of namespace,
  # with support for the following keys:
  #  :namespace, as described above
  #  :preserve_order, to rely on existing hash ordering
  #  for the string pairs "key=value"
  #
  # The string pairs "key=value" that form the query string
  # are sorted lexicographically in ascending order by default.
  #
  # This method is also aliased as +to_param+.
  def to_query(options_or_namespace = nil)
    if options_or_namespace.is_a?(Hash) && options_or_namespace.all? { |key, _value| @@valid_options_for_to_query.include?(key) }
      # support newer contract with an options hash
      namespace = options_or_namespace[:namespace]
      preserve_order = options_or_namespace[:preserve_order]
    else
      # support older contract with a single namespace argument
      namespace = options_or_namespace
      preserve_order = false
    end
    query = collect do |key, value|
      unless (value.is_a?(Hash) || value.is_a?(Array)) && value.empty?
        value.to_query(namespace ? "#{namespace}[#{key}]" : key)
      end
    end.compact
    query.sort! unless preserve_order || namespace.to_s.include?("[]")
    query.join("&")
  end

  alias_method :to_param, :to_query
end
