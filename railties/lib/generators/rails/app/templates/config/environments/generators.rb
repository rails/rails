# Settings specified here will take precedence over those in config/environment.rb

# No need to reload in generators environment, so do cache classes.
config.cache_classes = true

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Configure generators options (below are default values, delete them if you want).
config.generators do |g|
  g.helper          = true
  g.layout          = true
  g.orm             = :active_record
  g.stylesheets     = true
  g.template_engine = :erb
  g.test_framework  = :test_unit
  g.timestamps      = true
end
