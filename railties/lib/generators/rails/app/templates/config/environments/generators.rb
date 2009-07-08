# Settings specified here will take precedence over those in config/environment.rb

# Cache classes and log when you accidentally call methods on nil.
config.cache_classes = false
config.whiny_nils = true

# We do not need any framework on generators. They are loaded on demand.
config.frameworks.clear

# Configure generators. Below you have the default values, delete them if you want.
config.generators do |g|
  g.helper          = true
  g.layout          = true
  g.orm             = :active_record
  g.stylesheets     = true
  g.template_engine = :erb
  g.test_framework  = :test_unit
  g.timestamps      = true
end
