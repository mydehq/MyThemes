<div align="center">

# MyThemes

**Themes for MyDE/MyCTL**

</div>

---

## Installation

### Using MyCTL

```bash
myctl theme theme <theme-name>
```

## Adding New Themes

### Theme Structure

Each theme follows this standardized structure:

```
theme-name/
  ├── theme.yml          # Theme metadata and configuration
  ├── hooks.sh           # Installation and setup scripts
  └── src/               # Theme assets
      ├── cursors/       # Cursor themes
      ├── fonts/         # Font files
      ├── gtk/            # GTK theme package
      ├── qt/             # Qt theme configurations (kcolorscheme)
      │ └── qt5/          # Qt5-specific configurations (qt5ct color)
      └── rofi/           # Rofi theme styling (rasi)
```

### Adding Themes

```bash

# 0. clone the repo
git clone https://github.com/mydehq/MyThemes

# 1. Create theme directory
mkdir themes/your-theme-name

# 2. Add theme configuration
cat > themes/your-theme-name/theme.yml << EOF
theme:
  version: "1.0"
  desc: "Your theme description"
  author: "Your Name"
  repo: "https://github.com/your-repo"
EOF

# 3. Add theme assets in src/ directory
# 4. Submit pull request
```

### Publishing

Themes are automatically processed when pushed to `main`:

- Archives created as `theme-name-version.tar.gz`
- Published to `repo` branch
- Index updated with new theme metadata

## Related Resources

- **Main Repository**: [soymadip/MyDE](https://github.com/soymadip/MyDE)
- **Documentation**: [MyDE Wiki](https://soymadip.github.io/MyDE)
- **Theme Repo**: [Repo Branch](../../tree/repo)
- **CLI Tool**: [soymadip/MyCTL](https://github.com/soymadip/MyCTL)

---

<div align="center">

**Made with ❤️ by the MyDE Team**

</div>
