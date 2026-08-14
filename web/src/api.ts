export type Session = {
  token: string
  ownerKey: string
  email: string
  displayName?: string
}

export type LookupItem = {
  id: string
  name: string
  code?: string
  mainAccountId?: string
  costCenterId?: string
}

const TOKEN_KEY = 'wakeed.session'

export function loadSession(): Session | null {
  try {
    const raw = localStorage.getItem(TOKEN_KEY)
    return raw ? (JSON.parse(raw) as Session) : null
  } catch {
    return null
  }
}

export function saveSession(session: Session | null) {
  if (!session) localStorage.removeItem(TOKEN_KEY)
  else localStorage.setItem(TOKEN_KEY, JSON.stringify(session))
}

function authHeaders(session: Session | null): HeadersInit {
  if (!session?.token) return {}
  return {
    'x-wakeed-token': session.token,
    'x-owner-key': session.ownerKey,
  }
}

async function api<T>(
  path: string,
  options: RequestInit = {},
  session: Session | null = null,
): Promise<T> {
  const res = await fetch(path, {
    ...options,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...authHeaders(session),
      ...(options.headers || {}),
    },
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok || data?.success === false) {
    throw new Error(data?.message || `فشل الطلب (${res.status})`)
  }
  return data as T
}

export async function login(email: string, password: string) {
  return api<{ success: boolean; data: unknown }>('/api/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  })
}

export async function fetchSubscriptions(token: string) {
  return api<{ success: boolean; data: unknown }>('/api/auth/subscriptions', {}, {
    token,
    ownerKey: '',
    email: '',
  })
}

export async function fetchJournalTypes(session: Session) {
  return api<{ success: boolean; data: LookupItem[] }>('/api/lookups/journal-types', {}, session)
}

export async function fetchCurrencies(session: Session) {
  return api<{ success: boolean; data: LookupItem[] }>('/api/lookups/currencies', {}, session)
}

export async function fetchCostCenters(session: Session) {
  return api<{ success: boolean; data: LookupItem[] }>('/api/lookups/cost-centers', {}, session)
}

export async function fetchAccounts(session: Session, q = '') {
  const query = q ? `?q=${encodeURIComponent(q)}` : ''
  return api<{ success: boolean; data: LookupItem[] }>(`/api/lookups/accounts${query}`, {}, session)
}

export async function importRemittances(
  session: Session,
  rows: Record<string, unknown>[],
  defaults: Record<string, unknown>,
) {
  return api<{
    success: boolean
    successCount: number
    failCount: number
    results: Array<{
      index: number
      ok: boolean
      message: string
      payload?: Record<string, unknown>
    }>
  }>(
    '/api/import/remittances',
    {
      method: 'POST',
      body: JSON.stringify({ rows, defaults }),
    },
    session,
  )
}

export function extractToken(payload: unknown): string {
  if (!payload || typeof payload !== 'object') return ''
  const obj = payload as Record<string, unknown>
  const candidates = [
    obj.token,
    obj.access_token,
    obj.accessToken,
    obj.plainTextToken,
    (obj.data as Record<string, unknown> | undefined)?.token,
    (obj.data as Record<string, unknown> | undefined)?.access_token,
    (obj.user as Record<string, unknown> | undefined)?.token,
  ]
  for (const c of candidates) {
    if (typeof c === 'string' && c.trim()) return c.trim()
  }
  // sanctum sometimes returns token under nested structures
  const nested = JSON.stringify(obj)
  const m = nested.match(/"(?:plainTextToken|access_token|token)"\s*:\s*"([^"]+)"/)
  return m?.[1] || ''
}

export function extractSubscriptions(payload: unknown): Array<{ ownerKey: string; name: string }> {
  const list: unknown[] = Array.isArray(payload)
    ? payload
    : Array.isArray((payload as { data?: unknown })?.data)
      ? ((payload as { data: unknown[] }).data)
      : []

  return list
    .map((item) => {
      const row = item as Record<string, unknown>
      const ownerKey = String(
        row.ownerKey ||
          row.owner_key ||
          row.OwnerKey ||
          row.WAKEED_SCHEMA ||
          row.wakeedSchema ||
          row.key ||
          row.Key ||
          row.id ||
          row.Id ||
          '',
      )
      const name = String(
        row.name ||
          row.Name ||
          row.companyName ||
          row.CompanyName ||
          row.subscriptionName ||
          row.displayName ||
          row.DisplayName ||
          ownerKey,
      )
      return { ownerKey, name }
    })
    .filter((x) => x.ownerKey)
}
