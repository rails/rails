module Arel
  module Memory
    class Engine
      module CRUD
        def read(relation)
          relation.eval
        end

        def create(relation)
          relation.eval
        end
      end
      include CRUD
    end
  end
end
