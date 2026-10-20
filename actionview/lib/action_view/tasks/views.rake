# frozen_string_literal: true

namespace :views do
  desc "Compile views into tmp/compiled_views"
  task precompile: :environment do
    # Run Action View load hooks, which register handlers such as Jbuilder.
    require "action_view/base"
    # Read view paths directly rather than eager loading, which would load app code at build time.
    engines = [Rails.application, *Rails.application.railties.grep(Rails::Engine)]
    ActionView::PathRegistry.cast_file_system_resolvers(engines.flat_map { |engine| engine.paths["app/views"].existent })
    ActionView::Template::CompilationCache.precompile(Rails.root, ActionView::PathRegistry.all_resolvers)
  end
end
