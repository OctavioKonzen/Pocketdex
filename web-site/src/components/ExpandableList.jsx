// Lista em grade que abre os detalhes de um item logo abaixo da linha dele,
// empurrando os outros para baixo (mesma lógica da Pokédex). Usada na
// Enciclopédia (golpes, habilidades e itens).

import { AnimatePresence, m } from 'framer-motion'
import { memo, useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
import { Icon } from './ui'

const GAP = 8
const TOP_BAR = 72
const EASE = [0.65, 0, 0.35, 1]

const Row = memo(function Row({ items, columns, openKey, getKey, renderItem, onToggle, rowRef, children }) {
  return (
    <div ref={rowRef} style={{ marginBottom: GAP }}>
      <div className="grid" style={{ gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))`, gap: GAP }}>
        {items.map((item) => {
          const key = getKey(item)
          const open = key === openKey
          return (
            <button
              key={key}
              type="button"
              onClick={() => onToggle(item)}
              aria-expanded={open}
              className={`list-row flex w-full cursor-pointer items-center gap-3 rounded-2xl px-4 py-3 text-left shadow-sm ${open ? 'is-open' : ''}`}
            >
              {renderItem(item)}
              <Icon name={open ? 'up' : 'down'} className="ml-auto shrink-0 text-muted" />
            </button>
          )
        })}
      </div>
      <AnimatePresence initial={false}>{children}</AnimatePresence>
    </div>
  )
})

export default function ExpandableList({ items, getKey, renderItem, renderDetails, getTitle, minItemWidth = 320, accent = '#AB47BC' }) {
  const containerRef = useRef(null)
  const [width, setWidth] = useState(0)
  useLayoutEffect(() => {
    const el = containerRef.current
    const observer = new ResizeObserver(([entry]) => setWidth(entry.contentRect.width))
    observer.observe(el)
    setWidth(el.getBoundingClientRect().width)
    return () => observer.disconnect()
  }, [])
  const columns = Math.max(1, Math.min(3, Math.floor((width + GAP) / (minItemWidth + GAP)) || 1))

  const [openItem, setOpenItem] = useState(null)
  const openKey = openItem ? getKey(openItem) : null
  const openIndex = openItem ? items.findIndex((i) => getKey(i) === openKey) : -1
  const openRow = openIndex < 0 ? -1 : Math.floor(openIndex / columns)

  const rowRefs = useRef([])
  const rowRefSetters = useRef([])
  const rowRef = (row) => (rowRefSetters.current[row] ??= (el) => (rowRefs.current[row] = el))
  const returnScroll = useRef(null)
  const openRowRef = useRef(openRow)
  openRowRef.current = openRow

  // Fecha se o item sair da lista (busca/filtro).
  useEffect(() => {
    if (openItem && openIndex < 0) setOpenItem(null)
  }, [openItem, openIndex])

  const onToggle = useCallback(
    (item) => {
      const key = getKey(item)
      setOpenItem((current) => {
        if (current && getKey(current) === key) {
          // Fechar: volta para onde a página estava.
          if (returnScroll.current !== null) {
            const top = returnScroll.current
            requestAnimationFrame(() => window.scrollTo({ top, behavior: 'smooth' }))
            returnScroll.current = null
          }
          return null
        }
        if (!current) returnScroll.current = window.scrollY
        // Rola suavemente até a linha do item (o painel antigo acima já some).
        const previousRow = openRowRef.current
        const index = items.findIndex((i) => getKey(i) === key)
        const row = Math.floor(index / columns)
        requestAnimationFrame(() => {
          const el = rowRefs.current[row]
          if (!el) return
          let top = el.getBoundingClientRect().top + window.scrollY - TOP_BAR - 12
          if (previousRow >= 0 && previousRow < row) {
            const panel = rowRefs.current[previousRow]?.querySelector('[data-panel]')
            top -= panel ? panel.getBoundingClientRect().height : 0
          }
          window.scrollTo({ top: Math.max(0, top), behavior: 'smooth' })
        })
        return item
      })
    },
    [getKey, items, columns],
  )

  const rows = Math.ceil(items.length / columns)
  return (
    <div ref={containerRef}>
      {width > 0 &&
        Array.from({ length: rows }, (_, row) => (
          <Row
            key={row}
            items={items.slice(row * columns, row * columns + columns)}
            columns={columns}
            openKey={row === openRow ? openKey : null}
            getKey={getKey}
            renderItem={renderItem}
            onToggle={onToggle}
            rowRef={rowRef(row)}
          >
            {row === openRow && (
              <m.div
                key={`panel-${openKey}`}
                data-panel
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                transition={{ duration: 0.45, ease: EASE }}
                style={{ overflow: 'hidden' }}
              >
                <m.div
                  initial={{ scale: 0.96, y: -8 }}
                  animate={{ scale: 1, y: 0 }}
                  transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
                  className="mt-2 mb-2 rounded-3xl bg-card p-6 shadow-xl"
                  style={{ borderTop: `4px solid ${accent}` }}
                >
                  <div className="mb-4 flex items-center justify-between gap-3">
                    <h2 className="text-2xl font-black">{getTitle(openItem)}</h2>
                    <button type="button" onClick={() => onToggle(openItem)} aria-label="Fechar" className="cursor-pointer rounded-full p-2 text-muted transition hover:scale-110 hover:bg-white/10">
                      <Icon name="close" />
                    </button>
                  </div>
                  {renderDetails(openItem)}
                </m.div>
              </m.div>
            )}
          </Row>
        ))}
    </div>
  )
}
