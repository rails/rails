module ActiveRecord
  class ExplainSubscriber < ActiveSupport::LogSubscriber
    def sql(event)
      ActiveRecord::Base.collect_queries_for_explain(event.payload)
    end

    def logger
      ActiveRecord::Base.logger
    end

    attach_to :active_record
  end
end
