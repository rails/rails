# frozen_string_literal: true

require "active_support/benchmarkable"
require "action_view/helpers/capture_helper"
require "action_view/helpers/output_safety_helper"
require "action_view/helpers/tag_helper"
require "action_view/helpers/url_helper"
require "action_view/helpers/sanitize_helper"
require "action_view/helpers/text_helper"
require "action_view/helpers/active_model_helper"
require "action_view/helpers/asset_tag_helper"
require "action_view/helpers/asset_url_helper"
require "action_view/helpers/atom_feed_helper"
require "action_view/helpers/cache_helper"
require "action_view/helpers/content_exfiltration_prevention_helper"
require "action_view/helpers/controller_helper"
require "action_view/helpers/csp_helper"
require "action_view/helpers/csrf_helper"
require "action_view/helpers/date_helper"
require "action_view/helpers/debug_helper"
require "action_view/helpers/form_tag_helper"
require "action_view/helpers/form_helper"
require "action_view/helpers/form_options_helper"
require "action_view/helpers/javascript_helper"
require "action_view/helpers/number_helper"
require "action_view/helpers/rendering_helper"
require "action_view/helpers/translation_helper"

module ActionView
  # = Action View \Helpers
  #
  # Action View \Helpers provide helper methods to use with Action View that can be used for:
  # - Formatting dates, strings and numbers
  # - Creating HTML links to images, videos, stylesheets, etc...
  # - Sanitizing content
  # - Creating forms
  # - Localizing content
  #
  # You can read more about Action View \Helpers in the {Action View Helpers}[https://guides.rubyonrails.org/action_view_overview.html#helpers] guide.
  module Helpers
    extend ActiveSupport::Autoload

    autoload :Tags

    def self.eager_load!
      super
      Tags.eager_load!
    end

    extend ActiveSupport::Concern

    include ActiveSupport::Benchmarkable
    include ActiveModelHelper
    include AssetTagHelper
    include AssetUrlHelper
    include AtomFeedHelper
    include CacheHelper
    include CaptureHelper
    include ContentExfiltrationPreventionHelper
    include ControllerHelper
    include CspHelper
    include CsrfHelper
    include DateHelper
    include DebugHelper
    include FormHelper
    include FormOptionsHelper
    include FormTagHelper
    include JavaScriptHelper
    include NumberHelper
    include OutputSafetyHelper
    include RenderingHelper
    include SanitizeHelper
    include TagHelper
    include TextHelper
    include TranslationHelper
    include UrlHelper
  end
end
