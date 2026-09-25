// Grade de Pokémon. Ao clicar em um card, os detalhes abrem logo abaixo da
// linha dele, empurrando os outros cards; setas/evoluções levam o painel até
// o Pokémon escolhido com rolagem suave; ao fechar, a página volta para onde
// estava.

import { AnimatePresence, m } from 'framer-motion'
import { memo, useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
import DetailsPanel from './DetailsPanel'
import PokemonCard, { CARD_STYLE } from './PokemonCard'
import { Empty } from './ui'

const GAP = 16
const MAX_COLUMNS = 6
const TOP_BAR = 72
const EASE = [0.65, 0, 0.35, 1]

/** Linhas criadas por vez: as demais só são criadas ao rolar a página. */
const ROWS_PER_BATCH = 12

/** Uma linha de cards (+ o painel, se estiver aberto nela). Só é redesenhada quando muda. */
const GridRow = memo(function GridRow({ items, columns, hiddenId, onCardClick, noteFor, rowRef, children }) {
  return (
    <div
      ref={rowRef}
      style={{ marginBottom: GAP, contentVisibility: children ? 'visible' : 'auto', containIntrinsicSize: `auto ${CARD_STYLE.height}px` }}
    >
      <div className="grid" style={{ gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))`, gap: GAP }}>
        {items.map((p) => (
          <PokemonCard key={p.id} pokemon={p} hidden={p.id === hiddenId} onClick={onCardClick} note={noteFor?.(p)} />
        ))}
      </div>
      <AnimatePresence initial={false}>{children}</AnimatePresence>
    </div>
  )
})

function useWidth(ref) {
  const [width, setWidth] = useState(0)
  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const observer = new ResizeObserver(([entry]) => setWidth(entry.contentRect.width))
    observer.observe(el)
    setWidth(el.getBoundingClientRect().width)
    return () => observer.disconnect()
  }, [ref])
  return width
}

function useViewportHeight() {
  const [height, setHeight] = useState(window.innerHeight)
  useEffect(() => {
    const onResize = () => setHeight(window.innerHeight)
    window.addEventListener('resize', onResize)
    return () => window.removeEventListener('resize', onResize)
  }, [])
  return height
}

/** @param noteFor  etiqueta extra por Pokémon (ex.: habilidade oculta) */
export default function PokedexGrid({ pokemon, emptyText = 'Nenhum Pokémon encontrado.', noteFor }) {
  const containerRef = useRef(null)
  const rowRefs = useRef([])
  // Funções de referência estáveis por linha (não quebram o memo das linhas).
  const rowRefSetters = useRef([])
  const rowRef = (row) => (rowRefSetters.current[row] ??= (el) => (rowRefs.current[row] = el))
  const width = useWidth(containerRef)
  const viewport = useViewportHeight()

  const minCard = width < 640 ? 150 : 190
  const columns = Math.max(2, Math.min(MAX_COLUMNS, Math.floor((width + GAP) / (minCard + GAP)) || 2))
  const compact = width < 900
  const rowExtent = CARD_STYLE.height + GAP
  const panelHeight = Math.max(460, Math.min(756, viewport - TOP_BAR - rowExtent - GAP - 24))

  // {id, row, byClick, openCount} do Pokémon aberto.
  const [open, setOpen] = useState(null)
  const [tab, setTab] = useState(0)
  const returnScroll = useRef(null)

  const selectedIndex = open ? pokemon.findIndex((p) => p.id === open.id) : -1

  // Fecha se o Pokémon sair da lista (busca/filtro) ou se as colunas mudarem.
  useEffect(() => {
    if (open && selectedIndex < 0) setOpen(null)
  }, [open, selectedIndex])
  useEffect(() => {
    setOpen((o) => (o ? { ...o, row: pokemon.findIndex((p) => p.id === o.id) / columns | 0 } : o))
  }, [columns, pokemon])

  const scrollToRow = useCallback(
    (row, previousRow) => {
      const el = rowRefs.current[row]
      if (!el) return
      let top = el.getBoundingClientRect().top + window.scrollY - TOP_BAR - 12
      // O painel antigo (acima) vai fechar: o alvo já considera isso.
      if (previousRow !== null && previousRow < row) top -= (compact ? 0 : panelHeight) + GAP
      window.scrollTo({ top: Math.max(0, top), behavior: 'smooth' })
    },
    [compact, panelHeight],
  )

  const show = useCallback(
    (p, { byClick }) => {
      const index = pokemon.findIndex((x) => x.id === p.id)
      if (index < 0) return
      const row = Math.floor(index / columns)
      setOpen((current) => {
        if (!current) returnScroll.current = window.scrollY
        const changesRow = !current || current.row !== row
        if (changesRow) requestAnimationFrame(() => scrollToRow(row, current ? current.row : null))
        return {
          id: p.id,
          row,
          byClick: changesRow ? byClick || !current : current.byClick,
          openCount: changesRow ? (current?.openCount ?? 0) + 1 : current.openCount,
        }
      })
    },
    [pokemon, columns, scrollToRow],
  )

  const close = useCallback(() => {
    setOpen(null)
    if (returnScroll.current !== null) {
      window.scrollTo({ top: returnScroll.current, behavior: 'smooth' })
      returnScroll.current = null
    }
  }, [])

  // Referência sempre atual ao Pokémon aberto: o clique fica estável (não
  // força redesenhar todos os cards).
  const openRef = useRef(open)
  openRef.current = open
  const onCardClick = useCallback((p) => (openRef.current?.id === p.id ? close() : show(p, { byClick: true })), [close, show])
  const step = (delta) => {
    const next = pokemon[selectedIndex + delta]
    if (next) show(next, { byClick: false })
  }
  const navigateTo = (speciesId) => {
    const target = pokemon.find((p) => p.species === speciesId && p.default) ?? pokemon.find((p) => p.species === speciesId)
    if (target) show(target, { byClick: false })
  }

  // Teclado: ← → navegam, Esc fecha.
  useEffect(() => {
    if (!open) return
    const onKey = (e) => {
      if (e.target.closest('input, textarea, [role=dialog]')) return
      if (e.key === 'ArrowRight') step(1)
      else if (e.key === 'ArrowLeft') step(-1)
      else if (e.key === 'Escape') close()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  })

  const rows = Math.ceil(pokemon.length / columns)

  // Criação progressiva das linhas conforme a rolagem.
  const [rendered, setRendered] = useState(ROWS_PER_BATCH)
  const sentinelRef = useRef(null)
  useEffect(() => {
    setRendered(ROWS_PER_BATCH)
  }, [pokemon])
  useEffect(() => {
    const el = sentinelRef.current
    if (!el) return
    const observer = new IntersectionObserver(
      ([entry]) => entry.isIntersecting && setRendered((r) => r + ROWS_PER_BATCH),
      { rootMargin: '1500px 0px' },
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [rendered, rows])
  // O painel (e a linha seguinte, para as setas) sempre estão criados.
  const visibleRows = Math.min(rows, Math.max(rendered, open ? open.row + 2 : 0))

  return (
    <div ref={containerRef}>
      {pokemon.length === 0 && <Empty>{emptyText}</Empty>}
      {width > 0 &&
        Array.from({ length: visibleRows }, (_, row) => {
          const panelHere = open && open.row === row && selectedIndex >= 0
          return (
            <GridRow
              key={row}
              items={pokemon.slice(row * columns, row * columns + columns)}
              columns={columns}
              hiddenId={panelHere ? open.id : null}
              onCardClick={onCardClick}
              noteFor={noteFor}
              rowRef={rowRef(row)}
            >
              {panelHere && (
                <m.div
                  key={`panel-${row}`}
                  initial={{ height: 0, opacity: 0 }}
                  animate={{ height: 'auto', opacity: 1 }}
                  exit={{ height: 0, opacity: 0 }}
                  transition={{ duration: 0.45, ease: EASE }}
                  style={{ overflow: 'hidden' }}
                >
                  <m.div
                    key={open.openCount}
                    style={{ paddingTop: GAP, transformOrigin: `${((selectedIndex % columns) + 0.5) * (100 / columns)}% 0%` }}
                    initial={open.byClick ? { scale: 0.15, opacity: 0 } : false}
                    animate={{ scale: 1, opacity: 1 }}
                    transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
                  >
                    <DetailsPanel
                      speciesId={pokemon[selectedIndex].species}
                      height={panelHeight}
                      compact={compact}
                      tab={tab}
                      onTabChange={setTab}
                      onClose={close}
                      onNavigate={navigateTo}
                      hasPrevious={selectedIndex > 0}
                      hasNext={selectedIndex < pokemon.length - 1}
                      onPrevious={() => step(-1)}
                      onNext={() => step(1)}
                    />
                  </m.div>
                </m.div>
              )}
            </GridRow>
          )
        })}
      {visibleRows < rows && <div ref={sentinelRef} style={{ height: (rows - visibleRows) * (CARD_STYLE.height + GAP) }} />}
    </div>
  )
}
