// Escolha do idioma do site (português, inglês, francês ou espanhol).

import { language, LANGUAGES, setLanguage } from '../lib/i18n'

export default function LanguagePicker({ compact = false }) {
  return (
    <div className={`flex flex-wrap gap-2 ${compact ? 'justify-center' : ''}`} data-no-translate>
      {LANGUAGES.map((l) => (
        <button
          key={l.code}
          type="button"
          onClick={() => l.code !== language && setLanguage(l.code)}
          aria-pressed={l.code === language}
          className={`cursor-pointer rounded-full px-3 py-1.5 text-sm font-bold transition ${l.code === language ? 'bg-sky-500 text-white' : 'bg-surface hover:bg-white/10'}`}
        >
          {l.flag} {l.label}
        </button>
      ))}
    </div>
  )
}
