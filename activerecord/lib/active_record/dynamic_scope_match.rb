module ActiveRecord

  # = Active Record Dynamic Scope Match
  #
  # Provides dynamic attribute-based scopes such as <tt>scoped_by_price(4.99)</tt>
  # if, for example, the <tt>Product</tt> has an attribute with that name. You can
  # chain more <tt>scoped_by_* </tt> methods after the other. It acts like a named
  # scope except that it's dynamic.
  class DynamicScopeMatch
    def self.match(method)
      ds_match = new(method)
      ds_match.scope && ds_match
    end

    def initialize(method)
      @scope = nil
      if method.to_s =~ /^scoped_by_([_a-zA-Z]\w*)$/
        names = $1
        @scope = true
      end

      @attribute_names = names && names.split('_and_')
    end

    attr_reader :scope, :attribute_names
    alias :scope? :scope
  end
end
