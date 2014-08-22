require 'que'

Que::Job.class_eval do
  class << self; alias_method :original_enqueue, :enqueue; end
  def self.enqueue(*args)
    args.pop if args.last.is_a?(Hash)
    self.run(*args)
  end
end
