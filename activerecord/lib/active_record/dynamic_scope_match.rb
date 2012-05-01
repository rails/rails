module ActiveRecord

  # = Active Record Dynamic Scope Match
  #
  # Provides dynamic attribute-based scopes such as <tt>scoped_by_price(4.99)</tt>
  # if, for example, the <tt>Product</tt> has an attribute with that name. You can
  # chain more <tt>scoped_by_* </tt> methods after the other. It acts like a named
  # scope except that it's dynamic.
  class DynamicScopeMatch
    METHOD_PATTERN = /^scoped_by_([_a-zA-Z]\w*)$/

    def self.match(method)
      if method.to_s =~ METHOD_PATTERN
        new(true, $1 && $1.split('_and_'))
      end
    end

    def initialize(scope, attribute_names)
      @scope           = scope
      @attribute_names = attribute_names
    end

    attr_reader :scope, :attribute_names
    alias :scope? :scope

    def valid_arguments?(arguments)
      arguments.size >= @attribute_names.size
    end
  end
end
