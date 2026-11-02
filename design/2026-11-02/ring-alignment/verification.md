# Dashboard ring alignment

Reproduced in the native iPhone 17 Simulator with the populated, isolated DEBUG fixture and `extra-extra-extra-large` text. The nutrient title wrapped to two lines while Calories remained one line. The top-aligned column layout therefore put the circle centers at different heights. See [before-large-text.png](before-large-text.png).

Added a custom vertical alignment guide at each circle’s center and aligned the two columns to that guide. This permits both titles and details to wrap naturally. Numeric text within the fixed-size circle stays on one line and scales to its available width. The accessibility-size stacked layout is unchanged.

Verified the circles align at standard text and at the larger setting that reproduced the defect: [after.png](after.png), [after-large-text.png](after-large-text.png). Simulator text size restored to large and the app relaunched without fixture arguments. No real diary data was replaced.

Debug Simulator and physical iPhone builds passed. Installed on the paired physical iPhone.
