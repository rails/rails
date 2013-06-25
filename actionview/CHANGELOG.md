*   Add possibility to render partial from subfolder with inheritance.

    Partial started with `/` will be found as absolute path. Allow to template inheritance to render partial inside subfolders. Partials with slash in path name can be found only from views root folder.


    Before:

    If path will be as `/controller_name/head/menu`, it can be found only in `#{Rails.root}/app/views/controller_name/head/_menu.html.erb`
    Thus the code `render :partial => "/head/menu"`, obviously raise an exception:

        Missing partial /head/menu with {:handlers=>[:erb, :builder], :formats=>[:html], :locale=>[:en, :en]}. Searched in:
        * "/path/to/project/app/views"

    Meantime if partial path starts without any slashes (`render :partial => "menu"`), a partial status can be found in several pathes: `#{Rails.root}/app/views/controller_name/_menu.html` or `#{Rails.root}/app/views/controller_name/_menu.html`

    And not possible to set inheritance partial in subfolder.

    After:

    When path is prepended with leading slash, it should be handled 'as is' and calculate from view_path root.

        # For Admin::AccountsController < Admin::BaseController < ApplicationController

        # in view
        render '/users/account/sidebar' # renders app/views/users/account/_sidebar.html.erb

        # in controller
        def show
          render '/something/custom_show' # renders app/views/something/custom_show.html.erb
        end

        # in controller
        layout '/socials/facebook' # renders layout from app/views/layouts/socials/facebook.html.erb

    When path is not prepended with leading slash, it should be handled with controller path_prefixes.

        # For Admin::AccountsController < Admin::BaseController < ApplicationController

        # in view
        render 'users/account/sidebar'
        # tries app/views/admin/accounts/users/account/_sidebar.html.erb
        # then app/views/admin/base/users/account/_sidebar.html.erb
        # then app/views/application/users/account/_sidebar.html.erb

        # in controller
        def show
          render 'something/custom_show'
          # tries app/views/admin/accounts/something/custom_show.html.erb
          # then app/views/admin/base/something/custom_show.html.erb
          # then app/views/application/something/custom_show.html.erb
        end

        # in controller
        layout 'socials/facebook'
        # tries layout app/views/layouts/admin/accounts/socials/facebook.html.erb
        # then layout app/views/layouts/admin/base/socials/facebook.html.erb
        # then layout app/views/layouts/application/socials/facebook.html.erb

    *Alexey Osipenko*

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
