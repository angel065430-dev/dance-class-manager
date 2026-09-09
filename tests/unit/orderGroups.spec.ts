import { describe, expect, it } from 'vitest'
import { groupRowsByOrder } from '@/utils/orderGroups'

describe('groupRowsByOrder', () => {
  it('shows one payment group for multiple classes in the same order', () => {
    const result = groupRowsByOrder([
      { id: 'r1', order_id: 'o1', class_name: '週一班', total_amount: 1800 },
      { id: 'r2', order_id: 'o1', class_name: '週五班', total_amount: 1800 },
    ])
    expect(result).toHaveLength(1)
    expect(result[0].class_names).toEqual(['週一班', '週五班'])
    expect(result[0].total_amount).toBe(1800)
  })

  it('keeps different orders separate', () => {
    const result = groupRowsByOrder([
      { order_id: 'o1', class_name: '週一班' },
      { order_id: 'o2', class_name: '週三班' },
    ])
    expect(result.map((group) => group.order_id)).toEqual(['o1', 'o2'])
  })
})
