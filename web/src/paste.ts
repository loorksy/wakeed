export type ColumnKey =
  | 'Date'
  | 'OffLineNumber'
  | 'AccountID'
  | 'DetailAccountId'
  | 'Amount'
  | 'CurrencyID'
  | 'VoucherRate'
  | 'Notes'
  | 'CostCenterId'
  | 'JournalTypeId'
  | 'ignore'

export const COLUMN_LABELS: Record<ColumnKey, string> = {
  Date: 'التاريخ',
  OffLineNumber: 'رقم المرجع / الحوالة',
  AccountID: 'الحساب الرئيسي (صندوق/بنك)',
  DetailAccountId: 'حساب الطرف',
  Amount: 'المبلغ',
  CurrencyID: 'العملة',
  VoucherRate: 'سعر الصرف',
  Notes: 'البيان',
  CostCenterId: 'مركز التكلفة',
  JournalTypeId: 'نوع السند',
  ignore: 'تجاهل',
}

const ALIASES: Record<string, ColumnKey> = {
  تاريخ: 'Date',
  date: 'Date',
  thedate: 'Date',
  رقم: 'OffLineNumber',
  مرجع: 'OffLineNumber',
  الحوالة: 'OffLineNumber',
  رقمالحوالة: 'OffLineNumber',
  offlinenumber: 'OffLineNumber',
  reference: 'OffLineNumber',
  remittancenumber: 'OffLineNumber',
  الحسابالرئيسي: 'AccountID',
  صندوق: 'AccountID',
  بنك: 'AccountID',
  accountid: 'AccountID',
  mainaccountid: 'AccountID',
  حسابالطرف: 'DetailAccountId',
  الطرف: 'DetailAccountId',
  العميل: 'DetailAccountId',
  detailaccountid: 'DetailAccountId',
  toaccountid: 'DetailAccountId',
  المبلغ: 'Amount',
  amount: 'Amount',
  debit: 'Amount',
  مدين: 'Amount',
  العملة: 'CurrencyID',
  currency: 'CurrencyID',
  currencyid: 'CurrencyID',
  سعرالصرف: 'VoucherRate',
  rate: 'VoucherRate',
  voucherrate: 'VoucherRate',
  البيان: 'Notes',
  ملاحظات: 'Notes',
  notes: 'Notes',
  description: 'Notes',
  مركزالتكلفة: 'CostCenterId',
  costcenterid: 'CostCenterId',
  نوعالسند: 'JournalTypeId',
  journaltypeid: 'JournalTypeId',
}

function normalizeHeader(value: string) {
  return value
    .trim()
    .toLowerCase()
    .replace(/[\s_\-]+/g, '')
    .replace(/[()]/g, '')
}

function detectDelimiter(line: string) {
  const tab = (line.match(/\t/g) || []).length
  const semi = (line.match(/;/g) || []).length
  const comma = (line.match(/,/g) || []).length
  if (tab >= semi && tab >= comma && tab > 0) return '\t'
  if (semi >= comma && semi > 0) return ';'
  return ','
}

function splitLine(line: string, delimiter: string) {
  if (delimiter === '\t') return line.split('\t').map((c) => c.trim())
  const cells: string[] = []
  let current = ''
  let inQuotes = false
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i]
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"'
        i += 1
      } else {
        inQuotes = !inQuotes
      }
      continue
    }
    if (ch === delimiter && !inQuotes) {
      cells.push(current.trim())
      current = ''
      continue
    }
    current += ch
  }
  cells.push(current.trim())
  return cells
}

export function parsePaste(text: string) {
  const lines = text
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')
    .split('\n')
    .map((l) => l.trimEnd())
    .filter((l) => l.trim().length > 0)

  if (!lines.length) {
    return { headers: [] as string[], rows: [] as string[][], delimiter: ',' }
  }

  const delimiter = detectDelimiter(lines[0])
  const matrix = lines.map((line) => splitLine(line, delimiter))
  const width = Math.max(...matrix.map((r) => r.length))
  const normalized = matrix.map((row) => {
    const copy = [...row]
    while (copy.length < width) copy.push('')
    return copy
  })

  return {
    headers: normalized[0],
    rows: normalized.slice(1),
    delimiter,
  }
}

export function guessMapping(headers: string[]): ColumnKey[] {
  return headers.map((header) => {
    const key = normalizeHeader(header)
    return ALIASES[key] || 'ignore'
  })
}

export function mapRowsToObjects(
  headers: string[],
  rows: string[][],
  mapping: ColumnKey[],
): Record<string, string>[] {
  return rows
    .map((row) => {
      const obj: Record<string, string> = {}
      mapping.forEach((key, idx) => {
        if (!key || key === 'ignore') return
        obj[key] = (row[idx] ?? '').trim()
      })
      // keep raw headers for debugging if needed
      headers.forEach((h, idx) => {
        if (!obj[`_col_${idx}`]) obj[`_col_${idx}`] = row[idx] ?? ''
        if (h && !obj[`_header_${idx}`]) obj[`_header_${idx}`] = h
      })
      return obj
    })
    .filter((obj) => Object.values(obj).some((v) => String(v).trim() !== ''))
}

export const SAMPLE_PASTE = `التاريخ\tرقم الحوالة\tالحساب الرئيسي\tحساب الطرف\tالمبلغ\tالعملة\tسعر الصرف\tالبيان
14/08/2026\tTRX-1001\tUUID-صندوق\tUUID-عميل\t1500\tUUID-عملة\t1\tحوالة واردة
14/08/2026\tTRX-1002\tUUID-بنك\tUUID-مورد\t2300\tUUID-عملة\t1\tحوالة صادرة`
