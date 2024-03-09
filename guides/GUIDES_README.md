# Rails Guides Redesign 2024

## About the Project



## Editing Depedencies

The editing files for the Guides rebuild reside in `stylesrc` and use SCSS to improve developer experience. The code base relies on `include_media` (https://eduardoboucas.github.io/include-media/) to enable inline media-queries adjustments. We've also relied on the standard `noramlize.css` (https://necolas.github.io/normalize.css/) to help bring all browsers together.

## Building the Guides in Development

Currently, this `style.scss` is being compiled to `style.css` using CodeKit locally. As this goes towards final, we should add this processing into the build rake task.

## FAQ

### Why are you not using CSS variables?

Per the MDN documentation on CSS custom properties (https://developer.mozilla.org/en-US/docs/Web/CSS/Using_CSS_custom_properties), they are not supported in media or container queries at this point (Feb 2024). They may in future releases, and we should pivot to that when they are more wholistically supported. SCSS variables, because they are interpolated at build, serve a similar purpose and allow us the flexibilty to support much older browsers.

### Why do we include LTR and RTL?

LTR/RTL (Left to right/right to left) is a layout change based on the nature of the language the site is being displayed in. Arabic and Farsi are two well known "RTL" languages. If the site is automatically translated, then the layout will adjust (mirror horizontally) to be more in line with the text.