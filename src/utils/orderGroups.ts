export type WithOrderAndClass = { order_id: string; class_name: string }

export function groupRowsByOrder<T extends WithOrderAndClass>(rows: T[]) {
  const groups = new Map<string, T & { class_names: string[] }>()
  for (const row of rows) {
    const existing = groups.get(row.order_id)
    if (existing) existing.class_names.push(row.class_name)
    else groups.set(row.order_id, { ...row, class_names: [row.class_name] })
  }
  return [...groups.values()]
}
