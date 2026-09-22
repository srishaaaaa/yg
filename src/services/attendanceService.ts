import { supabase } from '../lib/supabase'
import type { PosBranch } from '../store/store'

export interface StaffMember {
  id: string
  branch: PosBranch
  name: string
  role: string
  is_active: boolean
}

export interface AttendanceRecord {
  id: string
  staff_member_id: string
  branch: PosBranch
  attendance_date: string
  clock_in: string | null
  clock_out: string | null
  status: 'present' | 'absent' | 'half_day' | 'leave'
  note: string
}

export async function fetchStaffMembers(branch: PosBranch): Promise<StaffMember[]> {
  const { data, error } = await supabase
    .from('staff_members')
    .select('id, branch, name, role, is_active')
    .eq('branch', branch)
    .eq('is_active', true)
    .order('name', { ascending: true })
  if (error) throw error
  return (data || []) as StaffMember[]
}

export async function createStaffMember(branch: PosBranch, name: string, role: string): Promise<StaffMember> {
  const { data, error } = await supabase
    .from('staff_members')
    .insert({ branch, name: name.trim(), role: role.trim() || 'staff' })
    .select('id, branch, name, role, is_active')
    .single()
  if (error) throw error
  return data as StaffMember
}

export async function deactivateStaffMember(id: string): Promise<void> {
  const { error } = await supabase.from('staff_members').update({ is_active: false }).eq('id', id)
  if (error) throw error
}

export async function fetchAttendanceForDate(branch: PosBranch, date: string): Promise<AttendanceRecord[]> {
  const { data, error } = await supabase
    .from('attendance_records')
    .select('id, staff_member_id, branch, attendance_date, clock_in, clock_out, status, note')
    .eq('branch', branch)
    .eq('attendance_date', date)
  if (error) throw error
  return (data || []) as AttendanceRecord[]
}

export async function fetchAttendanceForMonth(branch: PosBranch, monthStart: string, monthEnd: string): Promise<AttendanceRecord[]> {
  const { data, error } = await supabase
    .from('attendance_records')
    .select('id, staff_member_id, branch, attendance_date, clock_in, clock_out, status, note')
    .eq('branch', branch)
    .gte('attendance_date', monthStart)
    .lte('attendance_date', monthEnd)
  if (error) throw error
  return (data || []) as AttendanceRecord[]
}

export async function punchAttendance(staffMemberId: string, action: 'in' | 'out'): Promise<AttendanceRecord> {
  const { data, error } = await supabase.rpc('punch_attendance', {
    p_staff_member_id: staffMemberId,
    p_action: action,
  })
  if (error) throw error
  const row = Array.isArray(data) ? data[0] : data
  return row as AttendanceRecord
}

export async function overrideAttendanceStatus(
  branch: PosBranch,
  staffMemberId: string,
  date: string,
  status: AttendanceRecord['status']
): Promise<void> {
  const { error } = await supabase
    .from('attendance_records')
    .upsert(
      { staff_member_id: staffMemberId, branch, attendance_date: date, status },
      { onConflict: 'staff_member_id,attendance_date' }
    )
  if (error) throw error
}
