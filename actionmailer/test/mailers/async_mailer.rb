class AsyncMailer < BaseMailer
  self.queue = ActiveSupport::TestQueue.new
end
