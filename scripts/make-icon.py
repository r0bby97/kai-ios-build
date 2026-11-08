"""Export the selected generated mask artwork to Apple's required icon dimensions."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
image = Image.open(root / "Design/Kai-mask-source.png")
if image.width != image.height:
    raise ValueError("The selected icon source must be square")
image = image.convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
image.save(root / "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png", optimize=True)
