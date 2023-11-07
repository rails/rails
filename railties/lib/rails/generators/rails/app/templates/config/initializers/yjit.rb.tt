# Automatically enable YJIT if running Ruby 3.3 or newer,
# as it brings very sizeable performance improvements.
# Many users reported 15-25% improved latency.

# If you are deploying to a memory-constrained environment,
# you may want to delete this file, but otherwise, it's free
# performance.
if defined? RubyVM::YJIT.enable
  Rails.application.config.after_initialize do
    RubyVM::YJIT.enable
  end
end
