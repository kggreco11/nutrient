"""Render Nutrient's original vector mark. Requires Python with Pillow.
The checked-in 1024 px icon is ready for Xcode; this is only for regenerating it.
"""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
scale = 3
background, ink, accent = '#141619', '#F1F0EA', '#A3D3B7'
points = [(296, 744), (296, 280), (728, 744), (728, 280)]
image = Image.new('RGB', (1024 * scale, 1024 * scale), background)
draw = ImageDraw.Draw(image)
draw.line([(x * scale, y * scale) for x, y in points], fill=ink, width=80 * scale)
for x, y in points:
    draw.ellipse(((x - 40) * scale, (y - 40) * scale, (x + 40) * scale, (y + 40) * scale), fill=ink)
draw.ellipse((766 * scale, 186 * scale, 814 * scale, 234 * scale), fill=accent)
image = image.resize((1024, 1024), Image.Resampling.LANCZOS)
image.save(root / 'ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png')
vector = root / 'design/2026-11-01/identity/mark.svg'
vector.parent.mkdir(parents=True, exist_ok=True)
vector.write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" fill="{background}"/>
  <path d="M296 744V280L728 744V280" fill="none" stroke="{ink}" stroke-width="80" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="790" cy="210" r="24" fill="{accent}"/>
</svg>\n''')
print('Rendered original N mark and opaque 1024 px app icon')
