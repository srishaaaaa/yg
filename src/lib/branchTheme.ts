import type { PosBranch } from '../store/store'

export const branchLabel = (branch: PosBranch) => (branch === 'pos2' ? 'POS 2' : 'POS 1')

export const posAccent = (branch: PosBranch) => branch === 'pos2'
  ? { bg: 'bg-posTwo', bgLight: 'bg-posTwo-light', text: 'text-posTwo-dark', border: 'border-posTwo', hex: '#B8860B' }
  : { bg: 'bg-posOne', bgLight: 'bg-posOne-light', text: 'text-posOne-dark', border: 'border-posOne', hex: '#8B1A1A' }
