module ActiveRecord
  class DynamicScopeMatch
    def self.match(method)
      ds_match = self.new(method)
      ds_match.scope ? ds_match : nil
    end

    def initialize(method)
      @scope = true
      case method.to_s
      when /^scoped_by_([_a-zA-Z]\w*)$/
        names = $1
      else
        @scope = nil
      end
      @attribute_names = names && names.split('_and_')
    end

    attr_reader :scope, :attribute_names

    def scope?
      !@scope.nil?
    end
  end
end
