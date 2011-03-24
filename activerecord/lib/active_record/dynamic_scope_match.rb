module ActiveRecord

  # = Active Record Dynamic Scope Match
  #
  # Provides dynamic attribute-based scopes such as <tt>scoped_by_price(4.99)</tt>
  # if, for example, the <tt>Product</tt> has an attribute with that name. You can
  # chain more <tt>scoped_by_* </tt> methods after the other. It acts like a named
  # scope except that it's dynamic.
  class DynamicScopeMatch
    def self.match(method)
      return unless method.to_s =~ /^scoped_by_([_a-zA-Z]\w*)$/
      new(true, $1 && $1.split('_and_'))
    end

    def initialize(scope, attribute_names)
      @scope           = scope
      @attribute_names = attribute_names
    end

    attr_reader :scope, :attribute_names
    alias :scope? :scope
  end
end
