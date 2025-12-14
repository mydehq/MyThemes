// Fetches and renders theme data from index.json

async function loadRepoData() {
    try {
        const response = await fetch('./index.json');
        if (!response.ok) throw new Error('Failed to load index.json');
        
        const data = await response.json();
        
        // Populate repository info
        const repoName = document.getElementById('repo-name');
        const maxVersions = document.getElementById('max-versions');
        const lastUpdated = document.getElementById('last-updated');
        
        if (repoName && data.repo_name) {
            repoName.textContent = data.repo_name;
        }
        
        if (maxVersions && data.max_versions) {
            maxVersions.textContent = data.max_versions;
        }
        
        if (lastUpdated && data.release) {
            // Convert Unix timestamp to readable date
            const date = new Date(data.release * 1000);
            const formatted = date.toISOString().slice(0, 16).replace('T', ' ');
            lastUpdated.textContent = formatted;
        }
        
        // Populate theme count
        const themeCount = Object.keys(data.themes || {}).length;
        const themeCountBadge = document.querySelector('.badge');
        if (themeCountBadge) {
            themeCountBadge.textContent = themeCount;
        }
        
        // Populate themes list
        const themesList = document.getElementById('themes-list');
        if (themesList && data.themes) {
            const themes = Object.entries(data.themes).sort((a, b) => a[0].localeCompare(b[0]));
            
            if (themes.length === 0) {
                themesList.innerHTML = '<tr><td colspan="2" class="text-center text-secondary py-4">No themes available</td></tr>';
            } else {
                themesList.innerHTML = themes.map(([name, info]) => `
                    <tr>
                        <td>
                            <a href="./${name}/versions.json" class="fw-bold text-decoration-none text-maroon">${name}</a>
                        </td>
                        <td class="text-center">
                            <a href="./${name}/${info.latest}.tar.gz" class="text-decoration-none text-maroon">${info.latest}</a>
                        </td>
                    </tr>
                `).join('');
            }
        }
        
        // Populate mirrors list
        const mirrorsList = document.getElementById('mirrors-list');
        if (mirrorsList && data.mirrors) {
            if (data.mirrors.length === 0) {
                mirrorsList.innerHTML = '<li class="text-center text-secondary py-3">No mirrors configured</li>';
            } else {
                mirrorsList.innerHTML = data.mirrors.map(url => `
                    <li class="p-3 mb-2 border border-secondary border-opacity-25 rounded font-monospace text-nowrap overflow-x-auto no-scrollbar small">
                        ${url}
                    </li>
                `).join('');
            }
        }
        
    } catch (error) {
        console.error('Error loading repo data:', error);
        
        // Show helpful error message
        const themesList = document.getElementById('themes-list');
        if (themesList) {
            const isFileProtocol = window.location.protocol === 'file:';
            const errorMsg = isFileProtocol 
                ? `<div class="text-center py-4">
                       <div class="text-warning mb-2">⚠️ Cannot load themes</div>
                       <small class="text-secondary">This page requires an HTTP server to function.<br>
                       Please serve this directory via HTTP (e.g., using <code>python -m http.server</code> or <code>npx live-server</code>)</small>
                   </div>`
                : `<div class="text-center text-danger py-4">Failed to load themes. Please check your connection.</div>`;
            
            themesList.innerHTML = `<tr><td colspan="2">${errorMsg}</td></tr>`;
        }
    }
}

// Load data when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', loadRepoData);
} else {
    loadRepoData();
}
