<div align="center">

<h1>
    <img src="./src/icon.png" alt="MyTM" width="80">
    <p>MyTM</p>
</h1>

MyTM or My Theme Manager is a [MyCTL](https://github.com/mydehq/myctl) plugin for desktop theme management.
<br>
Supports gtk, qt, kde, rofi & others through templates

</div>

---

## Installation

> [!WARNING]
> MyTM is under development, nothing is finalized yet.  
> The MyCTL plugin system is not yet ready, so this is just individual script now.

### Add the Plugin to MyCTL

```bash
myctl plugin add mytm
```
This will automatically add `official` repo. it's hosted [here](../repo).

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
git clone https://github.com/mydehq/MyTM

# 1. Create theme directory
mkdir themes/your-theme-name

# 2. Add theme configuration
cat > themes/your-theme-name/theme.yml << EOF
version: "1.0"
desc: "Your theme description"
author: "Your Name"
url: "https://github.com/your-repo"
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

## Hosting your own theme Repo

MyTM theme repo can be hosted on any static hosting.  
The only key is to make sure the theme archives are accessible via https/http

If you use GitHub or GitLab, you can use CI/CD to automate the process.

### Initialize a repo

Open your terminal & run:

```bash
mytm repo init <repo_name> # replace <dir_name> with . to use current dir
```

This will make the `<repo_name>` dir & create necessary files, dirs.
Also `repo.name` will be added in config.yml.

### Edit the [config.yml](./config.yml)

Available options, Note that all are under `packaging` key:

1. `input-dir`: absolute/relative path of input themes dir.
2. `output-dir`: absolute/relative path of output dist dir.
3. `max-versions`: maximum number of versions to keep per theme.

4. `repo.name`: name/id of the repo, any string except 'official'. 
5. `repo.branch`: Git branch where themes will be published (if using CI/CD).
6. `repo.mirrors`:
   - Array of direct download URLs.
   - Use `${{theme}}` & `${{file}}` variables.
   - Will be tried in order if 1st mirror is not reachable.

7. `templates.readme`: Path to README.md template file.
8. `templates.index-html`: Path to index.html template file.

   **Available Variables in Templates:**
   - `${{repo-name}}`: Repository name.
   - `${{last-updated}}`: Time of generation.
   - `${{max-versions}}`: Configured max versions.
   - `${{mirrors}}`: Formatted list of mirrors (HTML list for index.html, Markdown list for README).
   - `${{mytm-repo}}`: Link to the official MyTM repository.
   - `${{themes}}`: The table of generated themes.

### Add Themes

1. Go to 'themes' dir: `cd themes`
2. Add themes, Follow [this guide](#adding-new-themes).
3. Go back to repo's root dir: `cd ..`
4. Run `mytm repo package`

Themes will be made in 'output-dir' set in config (default: 'dist').

## Related Resources

- **MyCTL Repository**: [mydehq/MyCTL](https://github.com/mydehq/MyCTL)
- **Documentation**: [mydehq/MyDE Wiki](https://mydehq.github.io/)
- **KireiSakura kit**: [soymadip/KireiSakura-Kit](https://github.com/soymadip/kireisakura-kit)
- **MyDE Repository**: [mydehq/MyDE](https://github.com/mydehq/MyDE)

---

<div align="center">

**Made with ❤️ by the MyDE Team**

</div>
