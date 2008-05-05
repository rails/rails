module Arel
  module Sql
    class Christener
      def name_for(relation)
        @used_names ||= Hash.new(0)
        @relation_names ||= Hash.new do |h, k|
          @used_names[k.name] += 1
          h[k] = k.name + (@used_names[k.name] > 1 ? "_#{@used_names[k.name]}" : '')
        end
        @relation_names[relation]
      end
    end
  end
end