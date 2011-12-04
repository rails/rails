require 'active_support/notifications'

module ActiveRecord
  class ExplainSubscriber
    def call(*args)
      ActiveRecord::Base.collect_queries_for_explain(args.last)
    end

    ActiveSupport::Notifications.subscribe("sql.active_record", new)
  end
end
