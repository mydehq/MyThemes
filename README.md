<div align="center">

<h1>
    <img src="./src/icon.svg" alt="MyTM" width="100">
    <br>
    MyTM
</h1>

MyTM or My Theme Manager is a [MyCTL](https://github.com/mydehq/myctl) plugin for desktop theme management.
<br>
Support gtk, qt, kde, rofi & others through templates

</div>

---

## Installation

### Add the Plugin to MyCTL

> [!WARNING]
> The MyCTL plugin step is not required for now.

```bash
myctl plugin add mytm
```

### Add the repo

```bash
mytm repo add -n official https://raw.githubusercontent.com/mydehq/mytm/refs/heads/repo/index.json
```

### Set a theme

```bash
mytm list
mytm set <theme-name>  # this will install and apply the theme
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

where:

- `theme.yml` contains theme metadata & dependencies (required)
- `hooks.sh` contains setup scripts (optional)
- `src/` dir contains theme files (optional)

### Adding Themes to this Repo

```bash

# 0. clone the repo
git clone https://github.com/mydehq/MyThemes

# 1. Create theme directory
mkdir themes/your-theme-name

# 2. Add theme configuration
cat > themes/your-theme-name/theme.yml << EOF
version: "1.0"
desc: "Your theme description"
author: "Your Name"
repo: "https://github.com/your-repo"
config:
  icon-theme: icon-theme-name
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
