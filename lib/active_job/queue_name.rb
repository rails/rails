module ActiveJob
  module QueueName
    mattr_accessor(:queue_base_name) { "active_jobs" }
    mattr_accessor(:queue_name)      { queue_base_name }

    def queue_as(part_name)
      self.queue_name = "#{queue_base_name}_#{part_name}"
    end
  end
end