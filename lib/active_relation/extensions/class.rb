class Class
  def memoize(method)
    define_method "#{method}_with_memoization" do |*args|
    end
    alias_method_chain method, :memoization
  end
end