require "backburner"

Backburner::Worker.class_eval do
  class << self; alias_method :original_enqueue, :enqueue; end
  def self.enqueue(job_class, args=[], opts={})
    job_class.perform(*args)
  end
end
