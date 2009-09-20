module Arel
  module HashExtensions
    def bind(relation)
      inject({}) do |bound, (key, value)|
        bound.merge(key.bind(relation) => value.bind(relation))
      end
    end

    Hash.send(:include, self)
  end
end
