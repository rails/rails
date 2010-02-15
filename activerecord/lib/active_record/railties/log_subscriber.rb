module ActiveRecord
  module Railties
    class LogSubscriber < Rails::LogSubscriber
      def sql(event)
        name = '%s (%.1fms)' % [event.payload[:name], event.duration]
        sql  = event.payload[:sql].squeeze(' ')

        if odd?
          name = color(name, :cyan, true)
          sql  = color(sql, nil, true)
        else
          name = color(name, :magenta, true)
        end

        debug "  #{name}  #{sql}"
      end

      def odd?
        @odd_or_even = !@odd_or_even
      end

      def logger
        ActiveRecord::Base.logger
      end
    end
  end
end