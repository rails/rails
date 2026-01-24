# Rails Guides Redesign 2024

## About the Project

The Rails Guides Visual Refresh occurred in Q1 2024, and was intended to bring the visual style of the guides inline with the rubyonrails.org site.

## Editing Dependencies

The editing files for the Guides rebuild reside in `stylesrc` and use SCSS to improve developer experience. The code base relies on `include_media` (https://eduardoboucas.github.io/include-media/) to enable inline media-queries adjustments. We've also relied on the standard `normalize.css` (https://necolas.github.io/normalize.css/) to help bring all browsers together.

## Building the Guides in Development

To generate new guides into static files, type `rake guides:generate` from inside the `guides` folder. If you make changes to the HTML or ERB, you'll need to remove the "output" directory before running this command. The master SCSS files (style.scss, highlight.scss) will compile as part of this process.

## FAQ

### Why are you not using CSS variables?

Per the MDN documentation on CSS custom properties (https://developer.mozilla.org/en-US/docs/Web/CSS/Using_CSS_custom_properties), they are not supported in media or container queries at this point (Feb 2024). They may in future releases, and we should pivot to that when they are more wholistically supported. SCSS variables, because they are interpolated at build, serve a similar purpose and allow us the flexibility to support much older browsers.

### Why do we include LTR and RTL?

LTR/RTL (Left to right/right to left) is a layout change based on the nature of the language the site is being displayed in. Arabic and Farsi are two well known "RTL" languages. If the site is automatically translated, then the layout will adjust (mirror horizontally) to be more in line with the text.

### Why is Dark Mode in a separate file

IncludeMedia does not handle `prefers-color-scheme` at this time, so it was extracted.