class Child1Job < ActiveJob::Base
  self.queue_adapter = 'test'
end

class Child2Job < ActiveJob::Base
  self.queue_adapter = 'inline'
end

class Child3Job < ActiveJob::Base
  #should use default queue adapter
end

class GrandChild1Job < Child1Job
  #should inherit queue_adapter from Child1Job
end

class GrandChild2Job < Child2Job
  #should inherit queue_adapter from Child2Job
end
