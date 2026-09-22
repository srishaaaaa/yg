import { useEffect, useState, useCallback } from 'react'
import { ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip, CartesianGrid } from 'recharts'
import { RefreshCw, Store, Phone, MapPin, ShoppingCart, Receipt, TrendingUp, Boxes, AlertTriangle, Layers, Tag, FileText, BarChart2 } from 'lucide-react'
import { supabase, isSupabaseConfigured } from '../../lib/supabase'
import { useAdminAuthStore, useProductStore, useSettingsStore, resolveBranch, type PosBranch } from '../../store/store'
import { formatCurrency } from '../../lib/retail'
import { BRAND_EN, BRAND_LOGO } from '../../lib/brand'
import type { TabKey } from '../../pages/Dashboard'

const posAccent = (branch: PosBranch) => branch === 'pos2'
  ? { bg: 'bg-posTwo', bgLight: 'bg-posTwo-light', text: 'text-posTwo-dark', border: 'border-posTwo' }
  : { bg: 'bg-posOne', bgLight: 'bg-posOne-light', text: 'text-posOne-dark', border: 'border-posOne' }

interface BranchHubProps {
  onNavigate: (tab: TabKey) => void
}

export default function BranchHub({ onNavigate }: BranchHubProps) {
  const activeBranch = useAdminAuthStore((s) => s.activeBranch)
  const role = useAdminAuthStore((s) => s.role)
  const branch = resolveBranch(activeBranch)
  const accent = posAccent(branch)
  const products = useProductStore((s) => s.products)
  const { settings, fetchSettings } = useSettingsStore()

  const [loading, setLoading] = useState(true)
  const [todaySales, setTodaySales] = useState(0)
  const [billsCount, setBillsCount] = useState(0)
  const [trend, setTrend] = useState<{ day: string; total: number }[]>([])
  const [topSkus, setTopSkus] = useState<{ name: string; qty: number }[]>([])

  const load = useCallback(async () => {
    if (!isSupabaseConfigured) { setLoading(false); return }
    setLoading(true)
    try {
      const since = new Date()
      since.setDate(since.getDate() - 6)
      since.setHours(0, 0, 0, 0)
      const todayStart = new Date()
      todayStart.setHours(0, 0, 0, 0)

      const { data: orders } = await supabase
        .from('orders')
        .select('id, total, created_at, items, status')
        .eq('branch', branch)
        .gte('created_at', since.toISOString())
        .order('created_at', { ascending: false })
        .limit(2000)

      const rows = (orders || []).filter((o) => String(o.status || '').toLowerCase() !== 'cancelled')

      const todayRows = rows.filter((o) => new Date(o.created_at) >= todayStart)
      setTodaySales(todayRows.reduce((sum, o) => sum + (Number(o.total) || 0), 0))
      setBillsCount(todayRows.length)

      const byDay: Record<string, number> = {}
      for (let i = 6; i >= 0; i--) {
        const d = new Date()
        d.setDate(d.getDate() - i)
        byDay[d.toISOString().slice(0, 10)] = 0
      }
      rows.forEach((o) => {
        const key = new Date(o.created_at).toISOString().slice(0, 10)
        if (key in byDay) byDay[key] += Number(o.total) || 0
      })
      setTrend(Object.entries(byDay).map(([day, total]) => ({ day: day.slice(5), total })))

      const skuQty: Record<string, number> = {}
      rows.forEach((o) => {
        const items = Array.isArray(o.items) ? o.items : []
        items.forEach((it: Record<string, unknown>) => {
          const name = String(it.name || it.product_name || 'Item')
          skuQty[name] = (skuQty[name] || 0) + (Number(it.quantity) || 0)
        })
      })
      setTopSkus(Object.entries(skuQty).sort((a, b) => b[1] - a[1]).slice(0, 5).map(([name, qty]) => ({ name, qty })))
    } catch (err) {
      console.error('[BranchHub] load error', err)
    } finally {
      setLoading(false)
    }
  }, [branch])

  useEffect(() => { void load() }, [load])
  useEffect(() => { void fetchSettings(branch) }, [fetchSettings, branch])

  const activeProducts = products.filter((p) => p.isActive)
  const inventoryValue = activeProducts.reduce((sum, p) => sum + (Number(p.price) || 0) * (Number(p.stockQuantity) || 0), 0)
  const lowStockCount = activeProducts.filter((p) => (Number(p.stockQuantity) || 0) <= 5).length
  const avgBill = billsCount > 0 ? todaySales / billsCount : 0

  const quickOps: { label: string; tab: TabKey; icon: React.ReactNode; primary?: boolean }[] = [
    { label: 'Open Store Dashboard & POS', tab: 'billing', icon: <ShoppingCart size={15} />, primary: true },
    { label: 'Stock Control', tab: 'inventory', icon: <Boxes size={15} /> },
    ...(role === 'admin' ? [{ label: 'Categories', tab: 'categories' as TabKey, icon: <Tag size={15} /> }] : []),
    { label: 'Advance Orders', tab: 'advance_orders', icon: <FileText size={15} /> },
    ...(role === 'admin' ? [{ label: 'Expenses', tab: 'expenses' as TabKey, icon: <Receipt size={15} /> }] : []),
    ...(role === 'admin' ? [{ label: 'Analytics', tab: 'pos_analytics' as TabKey, icon: <BarChart2 size={15} /> }] : []),
  ]

  return (
    <div className="space-y-5">
      {/* Branch header card */}
      <div className={`bg-white border-2 ${accent.border} rounded-2xl p-5 shadow-sm`}>
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className={`w-14 h-14 rounded-xl ${accent.bgLight} border ${accent.border} p-2 flex items-center justify-center shrink-0`}>
              <img src={BRAND_LOGO} alt={BRAND_EN} className="w-full h-full object-contain" />
            </div>
            <div>
              <div className="flex items-center gap-2 flex-wrap">
                <h2 className="text-lg font-black text-[#1A0E0E]">{BRAND_EN} — {branch === 'pos2' ? 'POS 2' : 'POS 1'}</h2>
                <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider ${accent.bgLight} ${accent.text}`}>
                  <span className={`h-1.5 w-1.5 rounded-full ${accent.bg}`} /> Active
                </span>
              </div>
              {settings && (
                <p className="text-xs text-gray-500 font-semibold flex flex-wrap items-center gap-x-3 gap-y-1 mt-1">
                  <span className="flex items-center gap-1"><Phone size={12} /> {settings.phone}</span>
                  <span className="flex items-center gap-1"><MapPin size={12} /> {settings.address}</span>
                </p>
              )}
            </div>
          </div>
          <button
            onClick={() => void load()}
            className="flex items-center gap-1.5 px-3 py-2 rounded-xl border border-gray-200 text-xs font-bold text-gray-600 hover:bg-gray-50 cursor-pointer"
          >
            <RefreshCw size={13} className={loading ? 'animate-spin' : ''} /> Refresh Metrics
          </button>
        </div>

        <div className="mt-4 pt-4 border-t border-gray-100">
          <p className="text-[10px] font-black uppercase tracking-wider text-gray-400 mb-2">Quick Branch Operations</p>
          <div className="flex flex-wrap gap-2">
            {quickOps.map((op) => (
              <button
                key={op.tab}
                onClick={() => onNavigate(op.tab)}
                className={op.primary
                  ? `flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-black text-white ${accent.bg} hover:opacity-90 cursor-pointer`
                  : 'flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold text-gray-700 border border-gray-200 hover:bg-gray-50 cursor-pointer'}
              >
                {op.icon} {op.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Stat cards */}
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-3">
        {[
          { label: "Today's Sales", value: formatCurrency(todaySales), icon: <TrendingUp size={15} /> },
          { label: 'Bills Count', value: String(billsCount), icon: <Receipt size={15} /> },
          { label: 'Average Bill', value: formatCurrency(avgBill), icon: <BarChart2 size={15} /> },
          { label: 'Inventory Value', value: formatCurrency(inventoryValue), icon: <Boxes size={15} /> },
          { label: 'Low Stock', value: String(lowStockCount), icon: <AlertTriangle size={15} />, warn: lowStockCount > 0 },
        ].map((s) => (
          <div key={s.label} className="bg-white border border-gray-200 rounded-2xl p-4 shadow-sm">
            <div className="flex items-center justify-between mb-2">
              <p className="text-[10px] font-black uppercase tracking-wide text-gray-400">{s.label}</p>
              <span className={s.warn ? 'text-red-500' : accent.text}>{s.icon}</span>
            </div>
            <p className={`text-lg font-black ${s.warn ? 'text-red-600' : 'text-[#1A0E0E]'}`}>{s.value}</p>
          </div>
        ))}
      </div>

      {/* Trend + top SKUs */}
      <div className="grid grid-cols-1 lg:grid-cols-[1.4fr_1fr] gap-4">
        <div className="bg-white border border-gray-200 rounded-2xl p-4 shadow-sm">
          <p className="text-xs font-black uppercase tracking-wide text-gray-500 mb-3">Recent Daily Sales Trend (Last 7 Days)</p>
          {trend.every((t) => t.total === 0) ? (
            <p className="text-xs text-gray-400 font-semibold py-8 text-center">No sales recorded yet this week.</p>
          ) : (
            <div style={{ width: '100%', height: 180 }}>
              <ResponsiveContainer>
                <LineChart data={trend}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#F0EAE0" />
                  <XAxis dataKey="day" tick={{ fontSize: 10 }} />
                  <YAxis tick={{ fontSize: 10 }} width={40} />
                  <Tooltip formatter={(v) => formatCurrency(Number(v) || 0)} />
                  <Line type="monotone" dataKey="total" stroke={branch === 'pos2' ? '#B8860B' : '#8B1A1A'} strokeWidth={2} dot={false} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          )}
        </div>
        <div className="bg-white border border-gray-200 rounded-2xl p-4 shadow-sm">
          <p className="text-xs font-black uppercase tracking-wide text-gray-500 mb-3">Top Performing SKUs</p>
          {topSkus.length === 0 ? (
            <p className="text-xs text-gray-400 font-semibold py-8 text-center">No transactions recorded yet.</p>
          ) : (
            <ul className="space-y-2">
              {topSkus.map((s, i) => (
                <li key={s.name} className="flex items-center justify-between text-xs">
                  <span className="font-bold text-gray-700 truncate flex items-center gap-2">
                    <span className={`w-5 h-5 rounded-full ${accent.bgLight} ${accent.text} font-black flex items-center justify-center text-[10px]`}>{i + 1}</span>
                    {s.name}
                  </span>
                  <span className="font-black text-gray-900">{s.qty} sold</span>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>

      {lowStockCount > 0 && (
        <div className="bg-amber-50 border border-amber-200 rounded-2xl p-4 flex items-start gap-3">
          <AlertTriangle size={18} className="text-amber-600 shrink-0 mt-0.5" />
          <div>
            <p className="text-xs font-black text-amber-900">Inventory Alerts</p>
            <p className="text-xs text-amber-700 font-semibold mt-0.5">
              {lowStockCount} item{lowStockCount === 1 ? '' : 's'} at or below minimum stock threshold in this branch.{' '}
              <button onClick={() => onNavigate('inventory')} className="underline font-black cursor-pointer">Open Stock Control</button>
            </p>
          </div>
        </div>
      )}
      <p className="text-[10px] text-gray-400 font-semibold flex items-center gap-1.5">
        <Store size={11} /> Branch-scoped data — isolated stock ledger and invoice sequence for this POS counter.
      </p>
    </div>
  )
}
