import type { PosBranch, StoreSettings } from '../store/store'
import { normalizeHex, shadeHex, tintHex } from './color'
import { BRAND_LOGO_POS1, BRAND_LOGO_POS2 } from './brand'

export const branchLabel = (branch: PosBranch) => (branch === 'pos2' ? 'POS 2' : 'POS 1')

export const branchLogo = (branch: PosBranch) => (branch === 'pos2' ? BRAND_LOGO_POS2 : BRAND_LOGO_POS1)

export const posAccent = (branch: PosBranch) => branch === 'pos2'
  ? { bg: 'bg-posTwo', bgLight: 'bg-posTwo-light', text: 'text-posTwo-dark', border: 'border-posTwo', hex: '#B8860B' }
  : { bg: 'bg-posOne', bgLight: 'bg-posOne-light', text: 'text-posOne-dark', border: 'border-posOne', hex: '#8B1A1A' }

const DEFAULT_BRANCH_COLOR: Record<PosBranch, string> = { pos1: '#8B1A1A', pos2: '#B8860B' }

/** Pushes each branch's saved Appearance color (Store Settings) onto the
 * `--pos-one*` / `--pos-two*` CSS custom properties that `bg-posOne`,
 * `text-posTwo-dark`, etc. resolve to (see tailwind.config.js), so the
 * picked color actually retheme's that branch's admin UI. */
export function applyBranchThemeVars(settingsByBranch: Partial<Record<PosBranch, StoreSettings>>) {
  const root = document.documentElement
  ;(['pos1', 'pos2'] as const).forEach((branch) => {
    const varPrefix = branch === 'pos2' ? '--pos-two' : '--pos-one'
    const color = normalizeHex(settingsByBranch[branch]?.themeColor || DEFAULT_BRANCH_COLOR[branch])
    root.style.setProperty(varPrefix, color)
    root.style.setProperty(`${varPrefix}-dark`, shadeHex(color))
    root.style.setProperty(`${varPrefix}-light`, tintHex(color))
  })
}
