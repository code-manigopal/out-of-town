Add a new scene to the browser prototype: $ARGUMENTS

1. Read docs/story/ for the relevant episode so the scene fits canon.
2. Read the matching prototype/browser/p<part>e<ep>.js file and follow its exact data format (lines with "NAME: text || subtitle", choices, puzzles, combat, fx, next).
3. Insert the scene and connect it from an existing scene so it is reachable.
4. Run `node tools/validate_prototype.js` and fix anything it reports until it shows `errors 0`.
5. Summarise what you added in two or three lines.
