import { useEffect } from 'react'

let lockCount = 0
let originalOverflow = ''
let originalPaddingRight = ''

/** Locks background page scroll while `active` is true — for modals/drawers
 * rendered via a portal, which otherwise let touch/wheel input scroll the
 * page behind them. Ref-counted so multiple modals can be open at once
 * (e.g. the global low-stock alarm popping up over another modal) without
 * one closing early and unlocking scroll while the other is still open.
 * Also compensates for the scrollbar-width layout shift on desktop. */
export function useBodyScrollLock(active: boolean) {
  useEffect(() => {
    if (!active) return

    if (lockCount === 0) {
      originalOverflow = document.body.style.overflow
      originalPaddingRight = document.body.style.paddingRight
      const scrollbarWidth = window.innerWidth - document.documentElement.clientWidth
      document.body.style.overflow = 'hidden'
      if (scrollbarWidth > 0) {
        document.body.style.paddingRight = `${scrollbarWidth}px`
      }
    }
    lockCount += 1

    return () => {
      lockCount = Math.max(0, lockCount - 1)
      if (lockCount === 0) {
        document.body.style.overflow = originalOverflow
        document.body.style.paddingRight = originalPaddingRight
      }
    }
  }, [active])
}
