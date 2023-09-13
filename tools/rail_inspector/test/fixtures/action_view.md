## Rails 7.1.0.beta1 (September 13, 2023) ##

*   Fix `simple_format` with blank `wrapper_tag` option returns plain html tag

    By default `simple_format` method returns the text wrapped with `<p>`. But if we explicitly specify
    the `wrapper_tag: nil` in the options, it returns the text wrapped with `<></>` tag.

    Before:

    ```ruby
    simple_format("Hello World", {},  { wrapper_tag: nil })
    # <>Hello World</>
    ```

    After:

    ```ruby
    simple_format("Hello World", {},  { wrapper_tag: nil })
    # <p>Hello World</p>
    ```

    *Akhil G Krishnan*, *Junichi Ito*

*   Don't double-encode nested `field_id` and `field_name` index values

    Pass `index: @options` as a default keyword argument to `field_id` and
    `field_name` view helper methods.

    *Sean Doyle*

*   Allow opting in/out of `Link preload` headers when calling `stylesheet_link_tag` or `javascript_include_tag`

    ```ruby
    # will exclude header, even if setting is enabled:
    javascript_include_tag("http://example.com/all.js", preload_links_header: false)

    # will include header, even if setting is disabled:
    stylesheet_link_tag("http://example.com/all.js", preload_links_header: true)
    ```

    *Alex Ghiculescu*
