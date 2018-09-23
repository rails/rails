*   Fix `current_page?` sometimes incorrectly returning `false`.

    When called with an URL which had a path ending on `/` and having query
    parameters, the `current_page?` function would return `false`.

    Fixes #33956.

    *Rien Maertens*

*   ActionView::Helpers::SanitizeHelper: support rails-html-sanitizer 1.1.0.

    *Juanito Fatas*

*   Added `phone_to` helper method to create a link from mobile numbers

    *Pietro Moro*

*   annotated_source_code returns an empty array so TemplateErrors without a
    template in the backtrace are surfaced properly by DebugExceptions.

    *Guilherme Mansur*, *Kasper Timm Hansen*

*   Add autoload for SyntaxErrorInTemplate so syntax errors are correctly raised by DebugExceptions.

    *Guilherme Mansur*, *Gannon McGibbon*

*   `RenderingHelper` supports rendering objects that `respond_to?` `:render_in`

    *Joel Hawksley*, *Natasha Umer*, *Aaron Patterson*, *Shawn Allen*, *Emily Plummer*, *Diana Mounter*, *John Hawthorn*, *Nathan Herald*, *Zaid Zawaideh*, *Zach Ahn*

*   Fix `select_tag` so that it doesn't change `options` when `include_blank` is present.

    *Younes SERRAJ*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/actionview/CHANGELOG.md) for previous changes.
