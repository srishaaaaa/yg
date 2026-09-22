import { ShieldCheck, User } from 'lucide-react'
import { posAccent, branchLabel } from '../../lib/branchTheme'
import type { PosBranch } from '../../store/store'

type RosterEntry = {
  id: string
  label: string
  role: 'ADMIN' | 'STAFF'
  branch: PosBranch | 'all'
}

function buildRoster(): RosterEntry[] {
  const adminId = String(import.meta.env.VITE_ADMIN_ID || import.meta.env.VITE_PORTAL_ID || 'admin').trim()
  const pos1Id = String(import.meta.env.VITE_POS1_STAFF_ID || import.meta.env.VITE_STAFF_ID || 'staff').trim()
  const pos2Id = String(import.meta.env.VITE_POS2_STAFF_ID || '').trim()

  const roster: RosterEntry[] = [
    { id: adminId, label: adminId, role: 'ADMIN', branch: 'all' },
    { id: pos1Id, label: pos1Id, role: 'STAFF', branch: 'pos1' },
  ]
  if (pos2Id) {
    roster.push({ id: pos2Id, label: pos2Id, role: 'STAFF', branch: 'pos2' })
  }
  return roster
}

export default function StaffMemberships() {
  const roster = buildRoster()

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-xl font-black text-[#1A0E0E]">Staff &amp; Memberships</h2>
          <p className="text-xs text-gray-500 font-semibold mt-1">Configured login accounts and the branch each one is restricted to.</p>
        </div>
        <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200 text-[10px] font-black uppercase">
          <ShieldCheck size={13} /> {roster.length} Accounts Configured
        </span>
      </div>

      <div className="bg-white border border-gray-200 rounded-2xl overflow-hidden shadow-sm">
        <div className="p-4 border-b border-gray-200 bg-[#FAFAFA]">
          <p className="text-xs font-black uppercase tracking-wider text-gray-800">Active Staff Roster ({roster.length})</p>
        </div>
        <ul className="divide-y divide-gray-100">
          {roster.map((entry) => {
            const accent = entry.branch === 'all' ? null : posAccent(entry.branch)
            return (
              <li key={`${entry.branch}-${entry.id}`} className="p-4 flex items-center justify-between gap-3 flex-wrap">
                <div className="flex items-center gap-3">
                  <div className={`w-9 h-9 rounded-full flex items-center justify-center font-black text-xs ${accent ? `${accent.bgLight} ${accent.text}` : 'bg-[#FBF6E9] text-[#B48811]'}`}>
                    {entry.label.slice(0, 1).toUpperCase()}
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <p className="text-sm font-black text-[#1A0E0E]">{entry.label}</p>
                      <span className={`px-1.5 py-0.5 rounded text-[9px] font-black uppercase tracking-wide ${entry.role === 'ADMIN' ? 'bg-[#FBF6E9] text-[#B48811] border border-[#E8D399]' : 'bg-gray-100 text-gray-600 border border-gray-200'}`}>
                        {entry.role}
                      </span>
                    </div>
                    <p className="text-xs text-gray-400 font-semibold flex items-center gap-1 mt-0.5">
                      <User size={11} /> Portal ID login
                    </p>
                  </div>
                </div>
                <div className="text-right">
                  <p className={`text-xs font-black ${accent ? accent.text : 'text-[#B48811]'}`}>
                    {entry.branch === 'all' ? 'All Branches' : branchLabel(entry.branch)}
                  </p>
                  <p className="text-[10px] text-gray-400 font-semibold flex items-center gap-1 justify-end mt-0.5">
                    <span className="h-1.5 w-1.5 rounded-full bg-emerald-500" /> Branch-Restricted Login
                  </p>
                </div>
              </li>
            )
          })}
        </ul>
      </div>

      <p className="text-[10px] text-gray-400 font-semibold">
        Accounts are configured via environment variables, not a database user table — branch restriction is enforced client-side at login, the same trust model as the rest of this portal.
      </p>
    </div>
  )
}
