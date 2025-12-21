// Fetches and renders theme versions from versions.json

async function loadVersions() {
  try {
    const repoResponse = await fetch("../index.json");
    if (repoResponse.ok) {
      const repoData = await repoResponse.json();
      if (repoData.repo_name) {
        const titleText = `MyTM / ${repoData.repo_name}`;
        const navbarTitle = document.getElementById("navbar-title");
        if (navbarTitle) {
          navbarTitle.textContent = titleText;
        }
      }
    }
  } catch (e) {
    console.debug("Could not fetch repo name:", e);
  }

  try {
    const response = await fetch("./versions.json");
    if (!response.ok) throw new Error("Failed to load versions.json");

    const versions = await response.json();

    // Get theme name from URL path
    const pathParts = window.location.pathname.split("/").filter((p) => p);
    const themeName = pathParts[pathParts.length - 1] || "Theme";

    // Update page title
    document.title = `${themeName} | MyTM`;

    // Update theme name in breadcrumb
    const themeNameEl = document.getElementById("theme-name");
    if (themeNameEl) {
      themeNameEl.textContent = themeName;
    }

    // Update version count
    const versionCount = document.getElementById("version-count");
    if (versionCount) {
      versionCount.textContent = versions.length;
    }

    // Populate versions list
    const versionsList = document.getElementById("versions-list");
    if (!versions || versions.length === 0) {
      versionsList.innerHTML =
        '<tr><td colspan="3" class="text-center text-secondary py-4">No versions available</td></tr>';
      return;
    }

    versionsList.innerHTML = versions
      .map(
        (v) => `
            <tr>
                <td class="text-center">
                  <a href="./${v.ver}.tar.gz" class="fw-bold text-decoration-none text-maroon">${v.ver}</a>
                </td>
                <td class="text-center">
                  <span class="badge bg-secondary">${v.hash.algo || "sha256"}</span>
                </td>
                <td class="text-center">
                  <span class="font-monospace small" style="word-break: break-all;">${v.hash.value}</span>
                </td>
            </tr>
        `,
      )
      .join("");
  } catch (error) {
    console.error("Error loading versions:", error);
    const versionsList = document.getElementById("versions-list");
    versionsList.innerHTML =
      '<tr><td colspan="3"><div class="text-center text-danger py-4">Version data unavailable.<br>Please contact the repository maintainer.</div></td></tr>';
  }
}

// Load data when DOM is ready
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", loadVersions);
} else {
  loadVersions();
}
