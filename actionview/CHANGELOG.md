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
