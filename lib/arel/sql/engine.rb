module Arel
  module Sql
    class Engine
      def self.new thing
        #warn "#{caller.first} -- Engine will be removed"
        thing
      end
    end
  end
end
