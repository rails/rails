## Rails 5.2.3 (March 27, 2019) ##

*   Prevent non-primary mouse keys from triggering Rails UJS click handlers.
    Firefox fires click events even if the click was triggered by non-primary mouse keys such as right- or scroll-wheel-clicks.
    For example, right-clicking a link such as the one described below (with an underlying ajax request registered on click) should not cause that request to occur.

    ```
    <%= link_to 'Remote', remote_path, class: 'remote', remote: true, data: { type: :json } %>
    ```

    Fixes #34541

    *Wolfgang Hobmaier*


## Rails 5.2.2.1 (March 11, 2019) ##

*   No changes.


## Rails 5.2.2 (December 04, 2018) ##

*   No changes.


## Rails 5.2.1.1 (November 27, 2018) ##

*   No changes.


## Rails 5.2.1 (August 07, 2018) ##

*   Fix leak of `skip_default_ids` and `allow_method_names_outside_object` options
    to HTML attributes.

    *Yurii Cherniavskyi*

*   Fix issue with `button_to`'s `to_form_params`

    `button_to` was throwing exception when invoked with `params` hash that
    contains symbol and string keys. The reason for the exception was that
    `to_form_params` was comparing the given symbol and string keys.

    The issue is fixed by turning all keys to strings inside
    `to_form_params` before comparing them.

    *Georgi Georgiev*

*   Fix JavaScript views rendering does not work with Firefox when using
    Content Security Policy.

    Fixes #32577.

    *Yuji Yaginuma*

*   Add the `nonce: true` option for `javascript_include_tag` helper to
    support automatic nonce generation for Content Security Policy.
    Works the same way as `javascript_tag nonce: true` does.

    *Yaroslav Markin*


## Rails 5.2.0 (April 09, 2018) ##

*   Pass the `:skip_pipeline` option in `image_submit_tag` when calling `path_to_image`.

    Fixes #32248.

    *Andrew White*

*   Allow the use of callable objects as group methods for grouped selects.

    Until now, the `option_groups_from_collection_for_select` method was only able to
    handle method names as `group_method` and `group_label_method` parameters,
    it is now able to receive procs and other callable objects too.

    *Jérémie Bonal*

*   Add `preload_link_tag` helper.

    This helper that allows to the browser to initiate early fetch of resources
    (different to the specified in `javascript_include_tag` and `stylesheet_link_tag`).
    Additionally, this sends Early Hints if supported by browser.

    *Guillermo Iguaran*

*   Change `form_with` to generates ids by default.

    When `form_with` was introduced we disabled the automatic generation of ids
    that was enabled in `form_for`. This usually is not an good idea since labels don't work
    when the input doesn't have an id and it made harder to test with Capybara.

    You can still disable the automatic generation of ids setting `config.action_view.form_with_generates_ids`
    to `false.`

    *Nick Pezza*

*   Fix issues with `field_error_proc` wrapping `optgroup` and select divider `option`.

    Fixes #31088

    *Matthias Neumayr*

*   Remove deprecated Erubis ERB handler.

    *Rafael Mendonça França*

*   Remove default `alt` text generation.

    Fixes #30096

    *Cameron Cundiff*

*   Add `srcset` option to `image_tag` helper.

    *Roberto Miranda*

*   Fix issues with scopes and engine on `current_page?` method.

    Fixes #29401.

    *Nikita Savrov*

*   Generate field ids in `collection_check_boxes` and `collection_radio_buttons`.

    This makes sure that the labels are linked up with the fields.

    Fixes #29014.

    *Yuji Yaginuma*

*   Add `:json` type to `auto_discovery_link_tag` to support [JSON Feeds](https://jsonfeed.org/version/1).

    *Mike Gunderloy*

*   Update `distance_of_time_in_words` helper to display better error messages
    for bad input.

    *Jay Hayes*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/actionview/CHANGELOG.md) for previous changes.
