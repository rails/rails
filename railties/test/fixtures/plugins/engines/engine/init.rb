# My app/models dir must be in the load path.
require 'engine_model'
raise LoadError, 'missing model from my app/models dir' unless defined?(EngineModel)
