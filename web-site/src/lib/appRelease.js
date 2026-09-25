// App Android (APK): cada versão é publicada em GitHub Releases pelo
// workflow .github/workflows/android-release.yml.
export const RELEASES_URL = 'https://github.com/OctavioKonzen/Pocketdex/releases'

let cached = null

/** Última versão publicada: { version, date, sizeMb, url } ou null se ainda não houver. */
export function getLatestRelease() {
  cached ??= fetch('https://api.github.com/repos/OctavioKonzen/Pocketdex/releases/latest', {
    headers: { Accept: 'application/vnd.github+json' },
  })
    .then((r) => (r.ok ? r.json() : null))
    .then((release) => {
      const apk = release?.assets?.find((a) => a.name.endsWith('.apk'))
      if (!apk) return null
      return {
        version: release.tag_name.replace(/^v/, ''),
        date: new Date(release.published_at).toLocaleDateString('pt-BR'),
        sizeMb: Math.round(apk.size / 1024 / 1024),
        url: apk.browser_download_url,
      }
    })
    .catch(() => null)
  return cached
}

/** Link de download: o arquivo da última versão, ou a página de versões. */
export async function getDownloadUrl() {
  return (await getLatestRelease())?.url ?? RELEASES_URL
}
