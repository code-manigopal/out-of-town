Run `node tools/export_story.js` to regenerate game/data/story/p1_scenes.json and game/data/story/p2_scenes.json (plus the CSVs in data/story/) from the browser prototype.

Then report the scene, line and choice counts per part, and list any scenes whose content is dynamic (computed from state) so they need manual handling in the Godot game. Then run `godot --headless --path game --script res://tests/run_tests.gd`.
