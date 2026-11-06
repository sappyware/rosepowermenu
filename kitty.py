import colorsys
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

KITTY_OUTPUT = Path.home() / ".config/kitty/wallpaper-theme.conf"
OMP_OUTPUT = Path.home() / ".config/oh-my-posh/wallpaper-theme.omp.json"
MANGO_OUTPUT = Path.home() / ".config/mango/config.conf"


def sh(cmd):
    try:
        return subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=3
        ).stdout.strip()
    except Exception:
        return ""


def detect():
    for q in ("awww", "swww"):
        if shutil.which(q):
            result = sh(q + " query")
            match = re.search(r"image:\s*(\S.*)", result)

            if match:
                return match.group(1).strip()

    pid = sh("pgrep -n -x swaybg")

    if pid.isdigit():
        try:
            args = Path(f"/proc/{pid}/cmdline").read_bytes()
            args = args.decode(errors="ignore").split("\0")

            for i, arg in enumerate(args[:-1]):
                if arg in ("-i", "--image"):
                    return args[i + 1]
        except Exception:
            pass

    return ""


def extract_colors(path, count=32):
    image = Image.open(path).convert("RGB")
    image.thumbnail((256, 256))

    quantized = image.quantize(colors=count, method=Image.Quantize.MEDIANCUT)

    palette = quantized.getpalette()
    colors = quantized.getcolors(256 * 256)

    result = []

    for frequency, index in colors:
        r, g, b = palette[index * 3 : index * 3 + 3]

        result.append(
            {
                "frequency": frequency,
                "rgb": (r, g, b),
                "hex": "#{:02x}{:02x}{:02x}".format(r, g, b),
                "hsv": colorsys.rgb_to_hsv(r / 255, g / 255, b / 255),
            }
        )

    return result


def luminance(rgb):
    channels = []

    for value in rgb:
        value /= 255

        value = value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4

        channels.append(value)

    return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722


def contrast(a, b):
    l1 = luminance(a)
    l2 = luminance(b)

    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)


def rgb_to_hex(rgb):
    return "#{:02x}{:02x}{:02x}".format(*rgb)


def make_readable(rgb, target, minimum=4.5):
    r, g, b = [v / 255 for v in rgb]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)

    best = rgb

    for step in range(101):
        new_v = step / 100

        candidate = tuple(round(x * 255) for x in colorsys.hsv_to_rgb(h, s, new_v))

        if contrast(candidate, target) >= minimum:
            best = candidate
            break

    return best


def pick_background(colors):
    dark = [c for c in colors if luminance(c["rgb"]) < 0.08]

    if dark:
        return max(dark, key=lambda c: c["frequency"])["rgb"]

    dominant = max(colors, key=lambda c: c["frequency"])

    return make_readable(dominant["rgb"], (255, 255, 255))


def pick_foreground(colors, background):
    candidates = sorted(colors, key=lambda c: c["frequency"], reverse=True)

    for color in candidates:
        if contrast(color["rgb"], background) >= 4.5:
            return color["rgb"]

    brightest = max(colors, key=lambda c: luminance(c["rgb"]))

    return make_readable(brightest["rgb"], background)


def hue_distance(a, b):
    d = abs(a - b)
    return min(d, 1 - d)


def build_palette(colors, background, foreground):

    chromatic = [c for c in colors if c["hsv"][1] > 0.20 and c["hsv"][2] > 0.18]

    roles = {
        1: 0.00,
        2: 0.33,
        3: 0.15,
        4: 0.62,
        5: 0.83,
        6: 0.50,
    }

    normal = [
        rgb_to_hex(background),
        None,
        None,
        None,
        None,
        None,
        None,
        rgb_to_hex(foreground),
    ]

    used = set()

    for index, target_hue in roles.items():
        if not chromatic:
            break

        chosen = min(
            chromatic,
            key=lambda c: (
                hue_distance(c["hsv"][0], target_hue) + (0.3 if c["hex"] in used else 0)
            ),
        )

        rgb = make_readable(chosen["rgb"], background, 3.0)

        normal[index] = rgb_to_hex(rgb)
        used.add(chosen["hex"])

    fallback = max(
        chromatic or colors, key=lambda c: c["frequency"] * max(c["hsv"][1], 0.1)
    )

    for index in range(1, 7):
        if normal[index] is None:
            normal[index] = rgb_to_hex(make_readable(fallback["rgb"], background, 3.0))

    normal[0] = rgb_to_hex(background)
    normal[7] = rgb_to_hex(foreground)

    bright = []

    for color in normal:
        r, g, b = [int(color[i : i + 2], 16) / 255 for i in (1, 3, 5)]

        h, s, v = colorsys.rgb_to_hsv(r, g, b)

        rgb = tuple(
            round(x * 255)
            for x in colorsys.hsv_to_rgb(h, min(1.0, s * 0.85), max(v, 0.72))
        )

        bright.append(rgb_to_hex(rgb))

    return normal, bright


def get_accent(colors):
    return max(colors, key=lambda c: c["frequency"] * c["hsv"][1])["hex"]


def generate_kitty(background, foreground, normal, bright, accent):
    config = f"""# Generated from current wallpaper.

background {background}
foreground {foreground}

selection_background {accent}
selection_foreground {background}

cursor {foreground}
cursor_text_color {background}

url_color {accent}

active_border_color {accent}
inactive_border_color {normal[0]}

active_tab_background {accent}
active_tab_foreground {background}
inactive_tab_background {background}
inactive_tab_foreground {foreground}

"""

    for i, color in enumerate(normal):
        config += f"color{i} {color}\n"

    for i, color in enumerate(bright):
        config += f"color{i + 8} {color}\n"

    KITTY_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    KITTY_OUTPUT.write_text(config)

    subprocess.run(
        ["kitty", "@", "set-colors", "--all", str(KITTY_OUTPUT)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def generate_omp(background, foreground, normal, bright, accent):

    theme = {
        "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
        "version": 4,
        "blocks": [
            {
                "alignment": "right",
                "segments": [
                    {
                        "background": background,
                        "foreground": normal[2],
                        "leading_diamond": "\ue0b6",
                        "options": {"style": "folder"},
                        "style": "diamond",
                        "template": "\ue5ff {{ .Path }}",
                        "trailing_diamond": "\ue0b4",
                        "type": "path",
                    },
                    {
                        "background": background,
                        "foreground": normal[6],
                        "leading_diamond": " \ue0b6",
                        "options": {"branch_icon": ""},
                        "style": "diamond",
                        "template": "{{ .HEAD }}",
                        "trailing_diamond": "\ue0b4",
                        "type": "git",
                    },
                    {
                        "background": background,
                        "foreground": normal[3],
                        "leading_diamond": " \ue0b6",
                        "style": "diamond",
                        "template": "\ue235{{ if .Error }}{{ .Error }}{{ else }}{{ if .Venv }}{{ .Venv }} {{ end }}{{ .Full }}{{ end }}",
                        "trailing_diamond": "\ue0b4",
                        "type": "python",
                    },
                    {
                        "background": background,
                        "foreground": normal[6],
                        "leading_diamond": " \ue0b6",
                        "style": "diamond",
                        "template": "\ue626{{ if .Error }}{{ .Error }}{{ else }}{{ .Full }}{{ end }}",
                        "trailing_diamond": "\ue0b4",
                        "type": "go",
                    },
                    {
                        "background": background,
                        "foreground": normal[2],
                        "leading_diamond": " \ue0b6",
                        "style": "diamond",
                        "template": "\ue718{{ if .PackageManagerIcon }}{{ .PackageManagerIcon }} {{ end }}{{ .Full }}",
                        "trailing_diamond": "\ue0b4",
                        "type": "node",
                    },
                    {
                        "background": background,
                        "foreground": normal[1],
                        "leading_diamond": " \ue0b6",
                        "style": "diamond",
                        "template": "\ue791{{ if .Error }}{{ .Error }}{{ else }}{{ .Full }}{{ end }}",
                        "trailing_diamond": "\ue0b4",
                        "type": "ruby",
                    },
                    {
                        "background": background,
                        "foreground": normal[1],
                        "leading_diamond": " \ue0b6",
                        "style": "diamond",
                        "template": "\ue738{{ if .Error }}{{ .Error }}{{ else }}{{ .Full }}{{ end }}",
                        "trailing_diamond": "\ue0b4",
                        "type": "java",
                    },
                    {
                        "background": background,
                        "foreground": normal[5],
                        "leading_diamond": " \ue0b6",
                        "style": "diamond",
                        "template": "\ue624{{ if .Error }}{{ .Error }}{{ else }}{{ .Full }}{{ end }}",
                        "trailing_diamond": "\ue0b4",
                        "type": "julia",
                    },
                    {
                        "background": background,
                        "foreground": accent,
                        "foreground_templates": [
                            '{{if eq "Charging" .State.String}}#40c4ff{{end}}',
                            '{{if eq "Discharging" .State.String}}#ff5722{{end}}',
                            '{{if eq "Full" .State.String}}#4caf50{{end}}',
                        ],
                        "leading_diamond": " \ue0b6",
                        "options": {
                            "charged_icon": "\u25cf ",
                            "charging_icon": "\u21e1 ",
                            "discharging_icon": "\u21e3 ",
                        },
                        "style": "diamond",
                        "template": "{{ if not .Error }}{{ .Icon }}{{ .Percentage }}{{ end }}{{ .Error }}",
                        "trailing_diamond": "\ue0b4",
                        "type": "battery",
                    },
                ],
                "type": "rprompt",
            },
            {
                "alignment": "left",
                "segments": [
                    {
                        "background": background,
                        "foreground": accent,
                        "leading_diamond": "\ue0b6",
                        "style": "diamond",
                        "template": "{{ .UserName }} \u276f",
                        "trailing_diamond": "\ue0b4 ",
                        "type": "session",
                    }
                ],
                "type": "prompt",
            },
        ],
    }

    OMP_OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    OMP_OUTPUT.write_text(json.dumps(theme, indent=2, ensure_ascii=False) + "\n")


def generate_mango(normal, bright, accent):

    def rgba(color):
        return "0x" + color.lstrip("#") + "ff"

    colors = {
        "border_color": rgba(bright[0]),
        "focus_color": rgba(accent),
        "split_color": rgba(normal[6]),
        "maximized_screen_color": rgba(normal[4]),
        "global_color": rgba(normal[3]),
    }

    MANGO_OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    if MANGO_OUTPUT.exists():
        lines = MANGO_OUTPUT.read_text().splitlines()
    else:
        lines = []

    updated = set()
    output = []

    for line in lines:
        match = re.match(
            r"^\s*(border_color|focus_color|split_color|maximized_screen_color|global_color)\s*=",
            line,
        )

        if match:
            key = match.group(1)

            if key not in updated:
                output.append(f"{key}={colors[key]}")
                updated.add(key)

            continue

        output.append(line)

    for key, value in colors.items():
        if key not in updated:
            output.append(f"{key}={value}")

    MANGO_OUTPUT.write_text("\n".join(output) + "\n")


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else ""

    if not path:
        path = detect()

    path = os.path.expanduser(path.strip())

    if not path or not os.path.isfile(path):
        print("Could not detect wallpaper.", file=sys.stderr)
        sys.exit(1)

    try:
        colors = extract_colors(path)

        background = pick_background(colors)
        foreground = pick_foreground(colors, background)

        normal, bright = build_palette(colors, background, foreground)

        accent = get_accent(colors)

        bg = rgb_to_hex(background)
        fg = rgb_to_hex(foreground)

        generate_kitty(bg, fg, normal, bright, accent)

        generate_omp(bg, fg, normal, bright, accent)

        generate_mango(normal, bright, accent)

        print()
        print("Wallpaper:", path)
        print("Background:", bg)
        print("Foreground:", fg)
        print("Accent:", accent)
        print()
        print("Generated:")
        print("Kitty:", KITTY_OUTPUT)
        print("Oh My Posh:", OMP_OUTPUT)
        print("MangoWM:", MANGO_OUTPUT)

    except Exception as error:
        print("Generation failed:", error, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
