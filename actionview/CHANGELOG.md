*   Remove deprecated `ActionView::Template#refresh`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionView::Template#original_encoding`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionView::Template#variants`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionView::Template#formats`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionView::Template#virtual_path=`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionView::Template#updated_at`.

    *Rafael Mendonça França*

*   Remove deprecated `updated_at` argument required on `ActionView::Template#initialize`.

    *Rafael Mendonça França*

*   Make `locals` argument required on `ActionView::Template#initialize`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionView::Template.finalize_compiled_template_methods`.

    *Rafael Mendonça França*

*   Remove deprecated `config.action_view.finalize_compiled_template_methods`

    *Rafael Mendonça França*

*   Remove deprecated support to calling `ActionView::ViewPaths#with_fallback` with a block.

    *Rafael Mendonça França*

*   Remove deprecated support to passing absolute paths to `render template:`.

    *Rafael Mendonça França*

*   Remove deprecated support to passing relative paths to `render file:`.

    *Rafael Mendonça França*

*   Remove support to template handlers that don't accept two arguments.

    *Rafael Mendonça França*

*   Remove deprecated pattern argument in `ActionView::Template::PathResolver`.

    *Rafael Mendonça França*

*   Remove deprecated support to call private methods from object in some view helpers.

    *Rafael Mendonça França*

*   `ActionView::Helpers::TranslationHelper#translate` accepts a block, yielding
    the translated text and the fully resolved translation key:

        <%= translate(".relative_key") do |translation, resolved_key| %>
          <span title="<%= resolved_key %>"><%= translation %></span>
        <% end %>

    *Sean Doyle*

*   Ensure cache fragment digests include all relevant template dependencies when
    fragments are contained in a block passed to the render helper. Remove the
    virtual_path keyword arguments found in CacheHelper as they no longer possess
    any function following 1581cab.

    Fixes #38984.

    *Aaron Lipman*

*   Deprecate `config.action_view.raise_on_missing_translations` in favor of
    `config.i18n.raise_on_missing_translations`.

    New generalized configuration option now determines whether an error should be raised
    for missing translations in controllers and views.

    *fatkodima*

*   Instrument layout rendering in `TemplateRenderer#render_with_layout` as `render_layout.action_view`,
    and include (when necessary) the layout's virtual path in notification payloads for collection and partial renders.

    *Zach Kemp*

*   `ActionView::Base.annotate_rendered_view_with_filenames` annotates HTML output with template file names.

    *Joel Hawksley*, *Aaron Patterson*

*   `ActionView::Helpers::TranslationHelper#translate` returns nil when
    passed `default: nil` without a translation matching `I18n#translate`.

    *Stefan Wrobel*

*   `OptimizedFileSystemResolver` prefers template details in order of locale,
    formats, variants, handlers.

    *Iago Pimenta*

*   Added `class_names` helper to create a CSS class value with conditional classes.

    *Joel Hawksley*, *Aaron Patterson*

*   Add support for conditional values to TagBuilder.

    *Joel Hawksley*

*   `ActionView::Helpers::FormOptionsHelper#select` should mark option for `nil` as selected.

    ```ruby
    @post = Post.new
    @post.category = nil

    # Before
    select("post", "category", none: nil, programming: 1, economics: 2)
    # =>
    # <select name="post[category]" id="post_category">
    #   <option value="">none</option>
    #  <option value="1">programming</option>
    #  <option value="2">economics</option>
    # </select>

    # After
    select("post", "category", none: nil, programming: 1, economics: 2)
    # =>
    # <select name="post[category]" id="post_category">
    #   <option selected="selected" value="">none</option>
    #  <option value="1">programming</option>
    #  <option value="2">economics</option>
    # </select>
    ```

    *bogdanvlviv*

*   Log lines for partial renders and started template renders are now
    emitted at the `DEBUG` level instead of `INFO`.

    Completed template renders are still logged at the `INFO` level.

    *DHH*

*   ActionView::Helpers::SanitizeHelper: support rails-html-sanitizer 1.1.0.

    *Juanito Fatas*

*   Added `phone_to` helper method to create a link from mobile numbers.

    *Pietro Moro*

*   annotated_source_code returns an empty array so TemplateErrors without a
    template in the backtrace are surfaced properly by DebugExceptions.

    *Guilherme Mansur*, *Kasper Timm Hansen*

*   Add autoload for SyntaxErrorInTemplate so syntax errors are correctly raised by DebugExceptions.

    *Guilherme Mansur*, *Gannon McGibbon*

*   `RenderingHelper` supports rendering objects that `respond_to?` `:render_in`.

    *Joel Hawksley*, *Natasha Umer*, *Aaron Patterson*, *Shawn Allen*, *Emily Plummer*, *Diana Mounter*, *John Hawthorn*, *Nathan Herald*, *Zaid Zawaideh*, *Zach Ahn*

*   Fix `select_tag` so that it doesn't change `options` when `include_blank` is present.

    *Younes SERRAJ*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/actionview/CHANGELOG.md) for previous changes.
