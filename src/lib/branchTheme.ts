import type { PosBranch, StoreSettings } from '../store/store'
import { normalizeHex, shadeHex, tintHex } from './color'
import { BRAND_LOGO_POS1, BRAND_LOGO_POS2 } from './brand'

/** User-facing branch name, themed to what that branch actually sells
 * (not a generic "POS 1"/"POS 2") — keep this the single source of truth
 * for the branch name shown anywhere in the UI. */
export const branchLabel = (branch: PosBranch) => (branch === 'pos2' ? 'Fireworks & Crackers POS' : 'Jute & Wedding POS')

/** Short chip/badge form of branchLabel for tight spaces (nav pills, badges). */
export const branchShortLabel = (branch: PosBranch) => (branch === 'pos2' ? 'Fireworks POS' : 'Jute & Wedding POS')

/** What this branch actually sells, for taglines/subtitles (matches the
 * wording baked into each branch's own logo art and Store Settings
 * business_type). */
export const branchSubtitle = (branch: PosBranch) =>
  branch === 'pos2' ? 'Fireworks & Crackers' : 'Wedding Card, Wedding Bag and Jute Bag Manufacturing'

/** Combined tagline for admin/global contexts that span both branches
 * (e.g. the Admin Orchestrator login tab) — showing only one branch's
 * business line there would be misleading since admin manages both. */
export const combinedBranchSubtitle = () => `${branchSubtitle('pos1')} + ${branchSubtitle('pos2')}`

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
