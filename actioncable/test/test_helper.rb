require File.expand_path('../../../load_paths', __FILE__)

require 'action_cable'
require 'active_support/testing/autorun'


require 'puma'

require 'mocha/setup'

require 'rack/mock'

# Require all the stubs and models
Dir[File.dirname(__FILE__) + '/stubs/*.rb'].each {|file| require file }

class ActionCable::TestCase < ActiveSupport::TestCase
  def wait_for_async
    e = Concurrent.global_io_executor
    until e.completed_task_count == e.scheduled_task_count
      sleep 0.1
    end
  end

  def run_in_eventmachine
    yield
    wait_for_async
  end
end
