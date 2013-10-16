*   Ensure ActionView::Digestor.cache is correctly cleaned up when
    combining recursive templates with ActionView::Resolver.caching = false
    
    *wyaeld*

*   Fix `collection_check_boxes` generated hidden input to use the name attribute provided
    in the options hash.

    *Angel N. Sciortino*

*   Fix some edge cases for AV `select` helper with `:selected` option

    *Bogdan Gusiev*

*   Ability to pass block to `select` helper

        <%= select(report, "campaign_ids") do %>
          <% available_campaigns.each do |c| -%>
            <%= content_tag(:option, c.name, value: c.id, data: { tags: c.tags.to_json }) %>
          <% end -%>
        <% end -%>

    *Bogdan Gusiev*

*   Handle `:namespace` form option in collection labels

    *Vasiliy Ermolovich*

*   Fix `form_for` when both `namespace` and `as` options are present

    `as` option no longer overwrites `namespace` option when generating
    html id attribute of the form element

    *Adam Niedzielski*

*   Fix `excerpt` when `:separator` is `nil`.

    *Paul Nikitochkin*

*   Only cache template digests if `config.cache_template_loading` id true.

    *Josh Lauer*, *Justin Ridgewell*

*   Fixed a bug where the lookup details were not being taken into account
    when caching the digest of a template - changes to the details now
    cause a different cache key to be used.

    *Daniel Schierbeck*

*   Added an `extname` hash option for `javascript_include_tag` method.

    Before:

        javascript_include_tag('templates.jst')
        # => <script src="/javascripts/templates.jst.js"></script>

    After:

        javascript_include_tag('templates.jst', extname: false )
        # => <script src="/javascripts/templates.jst"></script>

    *Nathan Stitt*

*   Fix `current_page?` when the URL contains escaped characters and the
    original URL is using the hexadecimal lowercased.

    *Rafael Mendonça França*

*   Fix `text_area` to behave like `text_field` when `nil` is given as
    value.

    Before:

        f.text_field :field, value: nil #=> <input value="">
        f.text_area :field, value: nil  #=> <textarea>value of field</textarea>

    After:

        f.text_area :field, value: nil  #=> <textarea></textarea>

    *Joel Cogen*

*   Element of the `grouped_options_for_select` can
    optionally contain html attributes as the last element of the array.

        grouped_options_for_select(
          [["North America", [['United States','US'],"Canada"], data: { foo: 'bar' }]]
        )

    *Vasiliy Ermolovich*

*   Fix default rendered format problem when calling `render` without :content_type option.
    It should return :html. Fix #11393.

    *Gleb Mazovetskiy* *Oleg* *kennyj*

*   Fix `link_to` with block and url hashes.

    Before:

        link_to(action: 'bar', controller: 'foo') { content_tag(:span, 'Example site') }
        # => "<a action=\"bar\" controller=\"foo\"><span>Example site</span></a>"

    After:

        link_to(action: 'bar', controller: 'foo') { content_tag(:span, 'Example site') }
        # => "<a href=\"/foo/bar\"><span>Example site</span></a>"

    *Murahashi Sanemat Kenichi*

*   Fix "Stack Level Too Deep" error when redering recursive partials.

    Fixes #11340.

    *Rafael Mendonça França*

*   Added an `enforce_utf8` hash option for `form_tag` method.

    Control to output a hidden input tag with name `utf8` without monkey
    patching.

    Before:

        form_tag
        # => '<form>..<input name="utf8" type="hidden" value="&#x2713;" />..</form>'

    After:

        form_tag
        # => '<form>..<input name="utf8" type="hidden" value="&#x2713;" />..</form>'

        form_tag({}, { :enforce_utf8 => false })
        # => '<form>....</form>'

    *ma2gedev*

*   Remove the deprecated `include_seconds` argument from `distance_of_time_in_words`,
    pass in an `:include_seconds` hash option to use this feature.

    *Carlos Antonio da Silva*

*   Remove deprecated block passing to `FormBuilder#new`.

    *Vipul A M*

*   Pick `DateField` `DateTimeField` and `ColorField` values from stringified options allowing use of symbol keys with helpers.

    *Jon Rowe*

*   Remove the deprecated `prompt` argument from `grouped_options_for_select`,
    pass in a `:prompt` hash option to use this feature.

    *kennyj*

*   Always escape the result of `link_to_unless` method.

    Before:

        link_to_unless(true, '<b>Showing</b>', 'github.com')
        # => "<b>Showing</b>"

    After:

        link_to_unless(true, '<b>Showing</b>', 'github.com')
        # => "&lt;b&gt;Showing&lt;/b&gt;"

    *dtaniwaki*

*   Use a case insensitive URI Regexp for #asset_path.

    This fix a problem where the same asset path using different case are generating
    different URIs.

    Before:

        image_tag("HTTP://google.com")
        # => "<img alt=\"Google\" src=\"/assets/HTTP://google.com\" />"
        image_tag("http://google.com")
        # => "<img alt=\"Google\" src=\"http://google.com\" />"

    After:

        image_tag("HTTP://google.com")
        # => "<img alt=\"Google\" src=\"HTTP://google.com\" />"
        image_tag("http://google.com")
        # => "<img alt=\"Google\" src=\"http://google.com\" />"

    *David Celis*

*   Element of the `collection_check_boxes` and `collection_radio_buttons` can
    optionally contain html attributes as the last element of the array.

    *Vasiliy Ermolovich*

*   Update the HTML `BOOLEAN_ATTRIBUTES` in `ActionView::Helpers::TagHelper`
    to conform to the latest HTML 5.1 spec. Add attributes `allowfullscreen`,
    `default`, `inert`, `sortable`, `truespeed`, `typemustmatch`. Fix attribute
    `seamless` (previously misspelled `seemless`).

    *Alex Peattie*

*   Fix an issue where partials with a number in the filename weren't being digested for cache dependencies.

    *Bryan Ricker*

*   First release, ActionView extracted from ActionPack

    *Piotr Sarnacki*, *Łukasz Strzałkowski*

Please check [4-0-stable (ActionPack's CHANGELOG)](https://github.com/rails/rails/blob/4-0-stable/actionpack/CHANGELOG.md) for previous changes.
