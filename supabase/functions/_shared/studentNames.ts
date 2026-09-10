export function normalizeStudentName(value: unknown): string {
  if (typeof value !== 'string') throw new Error('請填寫中文本名')
  const name = value.trim().normalize('NFC').replace(/\s+/g, ' ')
  if (!name || name.length > 80 || /[\p{Cc}\p{Cf}]/u.test(name))
    throw new Error('中文本名格式不正確')
  return name
}
export function normalizeLineDisplayName(value: unknown): string | null {
  if (value == null || value === '') return null
  if (typeof value !== 'string') throw new Error('LINE 顯示名字格式不正確')
  const name = value.trim().normalize('NFC')
  if (name.length > 100 || /[\p{Cc}\p{Cf}]/u.test(name))
    throw new Error('LINE 顯示名字格式不正確')
  return name || null
}
export function studentDisplayName(name: string | null, line: string | null): string {
  return `${name || '（未填寫姓名）'}${line ? `（${line}）` : ''}`
}
