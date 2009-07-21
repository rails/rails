module Bundler
  module Resolver
    module Inspect
      def gem_resolver_inspect(o)
        case o
        when Gem::Specification
          "#<Spec: #{o.full_name}>"
        when Array
          '[' + o.map {|x| gem_resolver_inspect(x)}.join(", ") + ']'
        when Set
          gem_resolver_inspect(o.to_a)
        when Hash
          '{' + o.map {|k,v| "#{gem_resolver_inspect(k)} => #{gem_resolver_inspect(v)}"}.join(", ") + '}'
        when Stack
          o.gem_resolver_inspect
        else
          o.inspect
        end
      end

      module_function :gem_resolver_inspect
    end
  end
end