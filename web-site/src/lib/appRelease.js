// App Android (APK): cada versão é publicada em GitHub Releases pelo
// workflow .github/workflows/android-release.yml.
export const RELEASES_URL = 'https://github.com/OctavioKonzen/Pocketdex/releases'

let cached = null

/** Última versão publicada: { version, date, sizeMb, url, url32 } ou null se ainda não houver.
 * `url` é o APK dos celulares 64 bits (quase todos); `url32`, o dos antigos. */
export function getLatestRelease() {
  cached ??= fetch('https://api.github.com/repos/OctavioKonzen/Pocketdex/releases/latest', {
    headers: { Accept: 'application/vnd.github+json' },
  })
    .then((r) => (r.ok ? r.json() : null))
    .then((release) => {
      const apks = release?.assets?.filter((a) => a.name.endsWith('.apk')) ?? []
      const apk = apks.find((a) => a.name === 'PocketDex.apk') ?? apks[0]
      const apk32 = apks.find((a) => a.name === 'PocketDex-32bits.apk')
      if (!apk) return null
      return {
        version: release.tag_name.replace(/^v/, ''),
        date: new Date(release.published_at).toLocaleDateString('pt-BR'),
        sizeMb: Math.round(apk.size / 1024 / 1024),
        url: apk.browser_download_url,
        url32: apk32?.browser_download_url ?? null,
      }
    })
    .catch(() => null)
  return cached
}

/** Link de download: o arquivo da última versão, ou a página de versões. */
export async function getDownloadUrl() {
  return (await getLatestRelease())?.url ?? RELEASES_URL
}
