class Symbol
  (Arel::Predications.instance_methods + [:not]).each do |sym|
    class_eval <<-RUBY, __FILE__, __LINE__ + 1
      def #{sym}
        ActiveRecord::PredicateBuilder::Operator.new(self, #{sym.inspect})
      end
    RUBY
  end
end # class Symbol