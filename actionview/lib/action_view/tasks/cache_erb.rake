# frozen_string_literal: true

namespace :rails do
  desc "Cache the compiled Ruby generated from the application's ERB templates"
  task cache_erb: :environment do
    require "action_view/erb_precompiler"

    Rails.application.eager_load!
    result = ActionView::ERBPrecompiler.call(ActionView::PathRegistry.all_resolvers)

    puts "Cached #{result.templates} #{'ERB template'.pluralize(result.templates)} " \
      "in #{result.entries} #{'entry'.pluralize(result.entries)}."
    if result.skipped_resolvers > 0
      warn "Skipped #{result.skipped_resolvers} non-enumerable " \
        "#{'resolver'.pluralize(result.skipped_resolvers)}."
    end
  end
end
