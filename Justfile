godot := env_var_or_default("GODOT", "C:/Users/young/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe")

# run the game
run:
    "{{godot}}" --path .

# open the editor
edit:
    "{{godot}}" --path . -e

# playtest lab — run one activity in isolation
lab:
    "{{godot}}" --path . res://scenes/dev/lab.tscn

# headless unit tests
test:
    "{{godot}}" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json

# headless unit tests for one script — just test-one tests/unit/test_day_clock.gd
test-one file:
    "{{godot}}" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://{{file}} -gexit

# import assets headlessly (after adding/editing scenes or assets)
import:
    "{{godot}}" --headless --path . --import

# rebuild global script-class cache (after adding any class_name script)
cache:
    "{{godot}}" --headless --editor --quit --path .

# export web build (needs the 4.7.1 web nothreads template; CI installs it). Extra flags pass through: just export-web --verbose
export-web *flags:
    mkdir -p build/web
    touch build/.gdignore
    "{{godot}}" --headless --path . {{flags}} --export-release "Web" build/web/index.html

# serve the web build locally
serve:
    npx serve build/web -p 8060
