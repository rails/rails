# frozen_string_literal: true

namespace :views do
  desc "Precompile the application's template handler output into the Bootsnap cache"
  task precompile: :environment do
    require "action_view/template_precompiler"

    Rails.application.eager_load!
    result = ActionView::TemplatePrecompiler.call(ActionView::PathRegistry.all_resolvers)

    puts "Precompiled #{result.templates} #{'template'.pluralize(result.templates)}."
    if result.skipped_resolvers > 0
      warn "Skipped #{result.skipped_resolvers} non-enumerable #{'resolver'.pluralize(result.skipped_resolvers)}."
    end
  end
end
