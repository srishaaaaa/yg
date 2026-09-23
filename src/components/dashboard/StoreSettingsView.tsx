import { useEffect, useState } from 'react'
import { Store, Phone, MapPin, Palette, RotateCcw, Save, Upload, Trash2, Loader2 } from 'lucide-react'
import { supabase } from '../../lib/supabase'
import { useAdminAuthStore, useSettingsStore, resolveBranch } from '../../store/store'
import { posAccent, branchShortLabel } from '../../lib/branchTheme'

const PRESET_COLORS = [
  '#1A0E0E', '#5C0D18', '#7A1220', '#8B1A1A', '#B8860B', '#D4AF37',
  '#8A6508', '#C2410C', '#0F766E', '#1D4ED8', '#6D28D9', '#BE185D',
]

type FormState = {
  name: string
  ownerName: string
  businessType: string
  phoneNumber: string
  shopContactNumber: string
  email: string
  address: string
  instagramId: string
  themeColor: string
  logoUrl: string
}

const emptyForm: FormState = {
  name: '', ownerName: '', businessType: '', phoneNumber: '', shopContactNumber: '',
  email: '', address: '', instagramId: '', themeColor: '#8B1A1A', logoUrl: '',
}

export default function StoreSettingsView() {
  const activeBranch = useAdminAuthStore((s) => s.activeBranch)
  const branch = resolveBranch(activeBranch)
  const accent = posAccent(branch)
  const { settings, fetchSettings } = useSettingsStore()
  const [form, setForm] = useState<FormState>(emptyForm)
  const [saving, setSaving] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null)

  useEffect(() => { void fetchSettings(branch) }, [fetchSettings, branch])

  useEffect(() => {
    if (!settings) return
    const [phoneNumber = '', shopContactNumber = ''] = settings.phone.split(',').map((p) => p.trim())
    setForm({
      name: settings.name,
      ownerName: settings.ownerName,
      businessType: settings.businessType,
      phoneNumber,
      shopContactNumber: shopContactNumber || phoneNumber,
      email: settings.email,
      address: settings.address,
      instagramId: settings.instagramId,
      themeColor: settings.themeColor,
      logoUrl: settings.logoUrl || '',
    })
  }, [settings])

  const handleReset = () => {
    if (!settings) return
    const [phoneNumber = '', shopContactNumber = ''] = settings.phone.split(',').map((p) => p.trim())
    setForm({
      name: settings.name, ownerName: settings.ownerName, businessType: settings.businessType,
      phoneNumber, shopContactNumber: shopContactNumber || phoneNumber, email: settings.email,
      address: settings.address, instagramId: settings.instagramId, themeColor: settings.themeColor,
      logoUrl: settings.logoUrl || '',
    })
    setMessage(null)
  }

  const handleSave = async () => {
    setSaving(true)
    setMessage(null)
    try {
      const phone = form.shopContactNumber && form.shopContactNumber !== form.phoneNumber
        ? `${form.phoneNumber}, ${form.shopContactNumber}`
        : form.phoneNumber
      const { error } = await supabase
        .from('store_settings')
        .update({
          name: form.name.trim(),
          owner_name: form.ownerName.trim(),
          business_type: form.businessType.trim(),
          phone,
          email: form.email.trim(),
          address: form.address.trim(),
          instagram_id: form.instagramId.trim(),
          theme_color: form.themeColor,
          logo_url: form.logoUrl || null,
          updated_at: new Date().toISOString(),
        })
        .eq('branch', branch)
      if (error) throw error
      await fetchSettings(branch)
      setMessage({ type: 'success', text: 'Store settings saved.' })
    } catch (err) {
      setMessage({ type: 'error', text: err instanceof Error ? err.message : 'Failed to save settings' })
    } finally {
      setSaving(false)
    }
  }

  const handleLogoUpload = async (file: File) => {
    setUploading(true)
    setMessage(null)
    try {
      const path = `${branch}/logo-${Date.now()}.${file.name.split('.').pop() || 'png'}`
      const { error: upErr } = await supabase.storage.from('branding').upload(path, file, { upsert: true })
      if (upErr) throw upErr
      const { data } = supabase.storage.from('branding').getPublicUrl(path)
      setForm((f) => ({ ...f, logoUrl: data.publicUrl }))
    } catch (err) {
      setMessage({ type: 'error', text: err instanceof Error ? err.message : 'Logo upload failed' })
    } finally {
      setUploading(false)
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-xl font-black text-[#1A0E0E]">Store Settings</h2>
          <p className="text-xs text-gray-500 font-semibold mt-1">Shop profile used across invoices, receipts and the app header.</p>
        </div>
        <div className="flex gap-2">
          <button onClick={handleReset} className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl border border-gray-200 text-xs font-bold text-gray-600 hover:bg-gray-50 cursor-pointer">
            <RotateCcw size={13} /> Reset
          </button>
          <button
            onClick={() => void handleSave()}
            disabled={saving}
            className={`flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-black text-white ${accent.bg} hover:opacity-90 disabled:opacity-60 cursor-pointer`}
          >
            {saving ? <Loader2 size={13} className="animate-spin" /> : <Save size={13} />} Save
          </button>
        </div>
      </div>

      {message && (
        <div className={`rounded-xl px-3.5 py-2.5 text-xs font-bold ${message.type === 'success' ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' : 'bg-red-50 text-red-600 border border-red-200'}`}>
          {message.text}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Shop Profile */}
        <div className="bg-white border border-gray-200 rounded-2xl p-5 shadow-sm space-y-3">
          <p className="text-xs font-black uppercase tracking-wide text-gray-700 flex items-center gap-1.5"><Store size={14} className={accent.text} /> Shop Profile</p>
          <p className="text-[10px] text-gray-400 font-semibold -mt-2">Logo, owner and shop name</p>
          <div className="flex items-center gap-3">
            <div className={`w-16 h-16 rounded-xl ${accent.bgLight} border ${accent.border} p-1.5 flex items-center justify-center overflow-hidden shrink-0`}>
              {form.logoUrl ? <img src={form.logoUrl} alt="Logo" className="w-full h-full object-contain" /> : <Store size={22} className={accent.text} />}
            </div>
            <div className="flex gap-2">
              <label className="flex items-center gap-1.5 px-3 py-2 rounded-xl border border-gray-200 text-[11px] font-bold text-gray-600 hover:bg-gray-50 cursor-pointer">
                {uploading ? <Loader2 size={12} className="animate-spin" /> : <Upload size={12} />} Replace Logo
                <input type="file" accept="image/*" className="hidden" onChange={(e) => e.target.files?.[0] && void handleLogoUpload(e.target.files[0])} />
              </label>
              {form.logoUrl && (
                <button onClick={() => setForm((f) => ({ ...f, logoUrl: '' }))} className="flex items-center gap-1.5 px-3 py-2 rounded-xl border border-red-200 text-[11px] font-bold text-red-600 hover:bg-red-50 cursor-pointer">
                  <Trash2 size={12} /> Remove
                </button>
              )}
            </div>
          </div>
          <div>
            <label className="block text-[10px] font-black uppercase tracking-wide text-gray-500 mb-1">Full Name</label>
            <input value={form.ownerName} onChange={(e) => setForm((f) => ({ ...f, ownerName: e.target.value }))} className="w-full h-10 px-3 rounded-xl border border-gray-200 bg-[#FBFAF6] text-sm font-bold outline-none focus:border-gray-400" />
          </div>
          <div>
            <label className="block text-[10px] font-black uppercase tracking-wide text-gray-500 mb-1">Shop Name</label>
            <input value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} className="w-full h-10 px-3 rounded-xl border border-gray-200 bg-[#FBFAF6] text-sm font-bold outline-none focus:border-gray-400" />
          </div>
          <div>
            <label className="block text-[10px] font-black uppercase tracking-wide text-gray-500 mb-1">Business Type</label>
            <input value={form.businessType} onChange={(e) => setForm((f) => ({ ...f, businessType: e.target.value }))} placeholder="e.g. Jute & Wedding Bags" className="w-full h-10 px-3 rounded-xl border border-gray-200 bg-[#FBFAF6] text-sm font-bold outline-none focus:border-gray-400" />
          </div>
        </div>

        {/* Contact Details */}
        <div className="bg-white border border-gray-200 rounded-2xl p-5 shadow-sm space-y-3">
          <p className="text-xs font-black uppercase tracking-wide text-gray-700 flex items-center gap-1.5"><Phone size={14} className={accent.text} /> Contact Details</p>
          <p className="text-[10px] text-gray-400 font-semibold -mt-2">Shop contact only — customer details are unaffected</p>
          <div>
            <label className="block text-[10px] font-black uppercase tracking-wide text-gray-500 mb-1">Phone Number</label>
            <input value={form.phoneNumber} onChange={(e) => setForm((f) => ({ ...f, phoneNumber: e.target.value }))} className="w-full h-10 px-3 rounded-xl border border-gray-200 bg-[#FBFAF6] text-sm font-bold outline-none focus:border-gray-400" />
          </div>
          <div>
            <label className="block text-[10px] font-black uppercase tracking-wide text-gray-500 mb-1">Shop Contact Number</label>
            <input value={form.shopContactNumber} onChange={(e) => setForm((f) => ({ ...f, shopContactNumber: e.target.value }))} className="w-full h-10 px-3 rounded-xl border border-gray-200 bg-[#FBFAF6] text-sm font-bold outline-none focus:border-gray-400" />
          </div>
          <div>
            <label className="block text-[10px] font-black uppercase tracking-wide text-gray-500 mb-1">Email ID</label>
            <input value={form.email} onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))} className="w-full h-10 px-3 rounded-xl border border-gray-200 bg-[#FBFAF6] text-sm font-bold outline-none focus:border-gray-400" />
          </div>
        </div>

        {/* Shop Information */}
        <div className="bg-white border border-gray-200 rounded-2xl p-5 shadow-sm space-y-3">
          <p className="text-xs font-black uppercase tracking-wide text-gray-700 flex items-center gap-1.5"><MapPin size={14} className={accent.text} /> Shop Information</p>
          <p className="text-[10px] text-gray-400 font-semibold -mt-2">Address and social profile</p>
          <div>
            <label className="block text-[10px] font-black uppercase tracking-wide text-gray-500 mb-1">Shop Address</label>
            <textarea value={form.address} onChange={(e) => setForm((f) => ({ ...f, address: e.target.value }))} rows={3} className="w-full px-3 py-2 rounded-xl border border-gray-200 bg-[#FBFAF6] text-sm font-bold outline-none focus:border-gray-400 resize-none" />
          </div>
          <div>
            <label className="block text-[10px] font-black uppercase tracking-wide text-gray-500 mb-1">Instagram ID</label>
            <input value={form.instagramId} onChange={(e) => setForm((f) => ({ ...f, instagramId: e.target.value }))} placeholder="@yourhandle" className="w-full h-10 px-3 rounded-xl border border-gray-200 bg-[#FBFAF6] text-sm font-bold outline-none focus:border-gray-400" />
          </div>
        </div>

        {/* Appearance */}
        <div className="bg-white border border-gray-200 rounded-2xl p-5 shadow-sm space-y-3">
          <p className="text-xs font-black uppercase tracking-wide text-gray-700 flex items-center gap-1.5"><Palette size={14} className={accent.text} /> Appearance</p>
          <p className="text-[10px] text-gray-400 font-semibold -mt-2">Preferred accent colour for this branch's cards &amp; buttons</p>
          <div className="flex flex-wrap gap-2">
            {PRESET_COLORS.map((c) => (
              <button
                key={c}
                onClick={() => setForm((f) => ({ ...f, themeColor: c }))}
                className={`w-8 h-8 rounded-full cursor-pointer ${form.themeColor.toLowerCase() === c.toLowerCase() ? 'ring-2 ring-offset-2 ring-gray-400' : ''}`}
                style={{ backgroundColor: c }}
                aria-label={c}
              />
            ))}
          </div>
          <div>
            <label className="block text-[10px] font-black uppercase tracking-wide text-gray-500 mb-1">Custom Colour</label>
            <div className="flex items-center gap-2">
              <input type="color" value={form.themeColor} onChange={(e) => setForm((f) => ({ ...f, themeColor: e.target.value }))} className="w-10 h-10 rounded-lg border border-gray-200 cursor-pointer" />
              <input value={form.themeColor} onChange={(e) => setForm((f) => ({ ...f, themeColor: e.target.value }))} className="flex-1 h-10 px-3 rounded-xl border border-gray-200 bg-[#FBFAF6] text-sm font-bold outline-none focus:border-gray-400 uppercase" />
            </div>
          </div>
          <div className="rounded-xl p-4 text-white" style={{ backgroundColor: form.themeColor }}>
            <p className="text-xs font-black uppercase tracking-wide">Card Preview</p>
            <p className="text-[11px] font-semibold opacity-90 mt-0.5">This colour is used for this branch's Store Settings/Branch Hub accents.</p>
          </div>
          <p className="text-[10px] text-gray-400 font-semibold">Saved with your profile — the rest of the app keeps its {branchShortLabel('pos1')} / {branchShortLabel('pos2')} maroon &amp; gold theme.</p>
        </div>
      </div>
    </div>
  )
}
