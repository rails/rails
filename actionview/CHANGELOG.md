## Rails 6.1.3 (February 17, 2021) ##

*   No changes.


## Rails 6.1.2.1 (February 10, 2021) ##

*   No changes.


## Rails 6.1.2 (February 09, 2021) ##

*   No changes.


## Rails 6.1.1 (January 07, 2021) ##

*   Fix lazy translation in partial with block.

    *Marek Kasztelnik*

*   Avoid extra `SELECT COUNT` queries when rendering Active Record collections.

    *aar0nr*

*   Link preloading keep integrity hashes in the header.

    *Étienne Barrié*

*   Add `config.action_view.preload_links_header` to allow disabling of
    the `Link` header being added by default when using `stylesheet_link_tag`
    and `javascript_include_tag`.

    *Andrew White*

*   The `translate` helper now resolves `default` values when a `nil` key is
    specified, instead of always returning `nil`.

    *Jonathan Hefner*


## Rails 6.1.0 (December 09, 2020) ##

*   SanitizeHelper.sanitized_allowed_attributes and SanitizeHelper.sanitized_allowed_tags
    call safe_list_sanitizer's class method

    Fixes #39586

    *Taufiq Muhammadi*

*   Change form_with to generate non-remote forms by default.

    `form_with` would generate a remote form by default. This would confuse
    users because they were forced to handle remote requests.

    All new 6.1 applications will generate non-remote forms by default.
    When upgrading a 6.0 application you can enable remote forms by default by
    setting `config.action_view.form_with_generates_remote_forms` to `true`.

    *Petrik de Heus*

*   Yield translated strings to calls of `ActionView::FormBuilder#button`
    when a block is given.

    *Sean Doyle*

*   Alias `ActionView::Helpers::Tags::Label::LabelBuilder#translation` to
    `#to_s` so that `form.label` calls can yield that value to their blocks.

    *Sean Doyle*

*   Rename the new `TagHelper#class_names` method to `TagHelper#token_list`,
    and make the original available as an alias.

        token_list("foo", "foo bar")
        # => "foo bar"

    *Sean Doyle*

*   ARIA Array and Hash attributes are treated as space separated `DOMTokenList`
    values. This is useful when declaring lists of label text identifiers in
    `aria-labelledby` or `aria-describedby`.

        tag.input type: 'checkbox', name: 'published', aria: {
          invalid: @post.errors[:published].any?,
          labelledby: ['published_context', 'published_label'],
          describedby: { published_errors: @post.errors[:published].any? }
        }
        #=> <input
              type="checkbox" name="published" aria-invalid="true"
              aria-labelledby="published_context published_label"
              aria-describedby="published_errors"
            >

    *Sean Doyle*

*   Remove deprecated `escape_whitelist` from `ActionView::Template::Handlers::ERB`.

    *Rafael Mendonça França*

*   Remove deprecated `find_all_anywhere` from `ActionView::Resolver`.

    *Rafael Mendonça França*

*   Remove deprecated `formats` from `ActionView::Template::HTML`.

    *Rafael Mendonça França*

*   Remove deprecated `formats` from `ActionView::Template::RawFile`.

    *Rafael Mendonça França*

*   Remove deprecated `formats` from `ActionView::Template::Text`.

    *Rafael Mendonça França*

*   Remove deprecated `find_file` from `ActionView::PathSet`.

    *Rafael Mendonça França*

*   Remove deprecated `rendered_format` from `ActionView::LookupContext`.

    *Rafael Mendonça França*

*   Remove deprecated `find_file` from `ActionView::ViewPaths`.

    *Rafael Mendonça França*

*   Require that `ActionView::Base` subclasses implement `#compiled_method_container`.

    *Rafael Mendonça França*

*   Remove deprecated support to pass an object that is not a `ActionView::LookupContext` as the first argument
    in `ActionView::Base#initialize`.

    *Rafael Mendonça França*

*   Remove deprecated `format` argument `ActionView::Base#initialize`.

    *Rafael Mendonça França*

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
