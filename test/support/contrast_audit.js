// Returns [{text, ratio, classes}] for visible text below `min` contrast.
// Colours are resolved through a canvas so any CSS colour syntax (oklch,
// color-mix, alpha) works, and backgrounds are composited from the page down.
(function (rootSelector, min) {
  const canvas = document.createElement("canvas"); canvas.width = canvas.height = 1
  const ctx = canvas.getContext("2d", { willReadFrequently: true })
  const paint = (layers) => {
    ctx.clearRect(0, 0, 1, 1)
    ctx.globalAlpha = 1; ctx.fillStyle = "#fff"; ctx.fillRect(0, 0, 1, 1)
    for (const [color, opacity] of layers) { ctx.globalAlpha = opacity; ctx.fillStyle = color; ctx.fillRect(0, 0, 1, 1) }
    return Array.from(ctx.getImageData(0, 0, 1, 1).data.slice(0, 3))
  }
  const lum = (rgb) => { const [r, g, b] = rgb.map((v) => { v /= 255; return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4 }); return 0.2126 * r + 0.7152 * g + 0.0722 * b }
  const ratio = (a, b) => { const [hi, lo] = [lum(a), lum(b)].sort((x, y) => y - x); return (hi + 0.05) / (lo + 0.05) }
  const out = []
  for (const el of document.querySelectorAll(`${rootSelector} *`)) {
    const own = Array.from(el.childNodes).filter((n) => n.nodeType === 3).map((n) => n.textContent.trim()).join(" ").trim()
    if (!own || !el.checkVisibility({ opacityProperty: true, visibilityProperty: true })) continue
    if (el.closest("[aria-hidden='true']")) continue // decorative, e.g. "•" separators
    const chain = []; for (let n = el; n; n = n.parentElement) chain.unshift(n)
    const layers = chain.map((n) => { const s = getComputedStyle(n); return [s.backgroundColor, parseFloat(s.opacity)] })
      .filter(([c]) => c && c !== "rgba(0, 0, 0, 0)" && c !== "transparent")
    const bg = paint(layers)
    const style = getComputedStyle(el)
    const fg = paint([...layers, [style.color, 1]])
    const r = ratio(fg, bg)
    if (r < min) out.push({ text: own.slice(0, 40), ratio: Math.round(r * 100) / 100, classes: el.className.toString().slice(0, 90) })
  }
  return out
})
