# frozen_string_literal: true

require "que"

Que::Job.class_eval do
  class << self; alias_method :original_enqueue, :enqueue; end
  def self.enqueue(*args)
    if args.last.is_a?(Hash)
      options = args.pop
      options.delete(:run_at)
      options.delete(:priority)
      options.delete(:queue)
      args << options unless options.empty?
    end
    run(*args)
  end
end

Que::ActiveJob::WrapperExtensions.class_eval do
  def run(args)
    super(args.deep_stringify_keys)
  end
end
