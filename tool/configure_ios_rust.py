from pathlib import Path
import shutil
import sys


root = Path(__file__).resolve().parent.parent
source = Path(sys.argv[1]).resolve()
runner_dir = root / "ios" / "Runner"
destination = runner_dir / "libcourse_table_parser.a"
shutil.copy2(source, destination)

linker_setting = (
    '\nOTHER_LDFLAGS = $(inherited) '
    '-force_load "$(PROJECT_DIR)/Runner/libcourse_table_parser.a"\n'
)
for name in ("Debug.xcconfig", "Release.xcconfig"):
    config = root / "ios" / "Flutter" / name
    text = config.read_text(encoding="utf-8")
    if "libcourse_table_parser.a" not in text:
        config.write_text(text.rstrip() + linker_setting, encoding="utf-8")
