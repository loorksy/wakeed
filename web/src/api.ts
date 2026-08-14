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

export type ApiErrorBody = {
  success?: boolean
  message?: string
  data?: unknown
  results?: unknown
  successCount?: number
  failCount?: number
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

function pickErrorMessage(data: ApiErrorBody, status: number): string {
  if (typeof data?.message === 'string' && data.message.trim()) return data.message
  if (typeof data?.data === 'string' && data.data.trim()) return data.data
  if (data?.data && typeof data.data === 'object') {
    const nested = data.data as Record<string, unknown>
    for (const key of ['message', 'Message', 'title', 'Title', 'error', 'Error', 'detail']) {
      if (typeof nested[key] === 'string' && String(nested[key]).trim()) {
        return String(nested[key])
      }
    }
  }
  return `فشل الطلب (${status})`
}

async function api<T>(
  path: string,
  options: RequestInit = {},
  session: Session | null = null,
  opts?: { allowBusinessFailure?: boolean },
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

  const data = (await res.json().catch(() => ({}))) as ApiErrorBody

  // Import endpoints may return HTTP 200 with success:false + per-row results.
  if (opts?.allowBusinessFailure) {
    if (!res.ok) throw new Error(pickErrorMessage(data, res.status))
    return data as T
  }

  if (!res.ok || data?.success === false) {
    throw new Error(pickErrorMessage(data, res.status))
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
    message?: string
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
    { allowBusinessFailure: true },
  )
}

function digStrings(value: unknown, path: string[] = [], out: Array<{ path: string; value: string }> = []) {
  if (typeof value === 'string' && value.trim()) {
    out.push({ path: path.join('.'), value: value.trim() })
    return out
  }
  if (Array.isArray(value)) {
    value.forEach((item, i) => digStrings(item, [...path, String(i)], out))
    return out
  }
  if (value && typeof value === 'object') {
    Object.entries(value as Record<string, unknown>).forEach(([k, v]) => {
      digStrings(v, [...path, k], out)
    })
  }
  return out
}

export function extractToken(payload: unknown): string {
  if (!payload || typeof payload !== 'object') return ''
  const obj = payload as Record<string, unknown>

  const directKeys = [
    'token',
    'access_token',
    'accessToken',
    'plainTextToken',
    'auth_token',
    'api_token',
  ]
  for (const key of directKeys) {
    if (typeof obj[key] === 'string' && obj[key].trim()) return String(obj[key]).trim()
  }

  for (const nestKey of ['data', 'user', 'result', 'Result', 'Data']) {
    const nested = obj[nestKey]
    if (nested && typeof nested === 'object') {
      const n = nested as Record<string, unknown>
      for (const key of directKeys) {
        if (typeof n[key] === 'string' && n[key].trim()) return String(n[key]).trim()
      }
      // Sanctum style: { token: { plainTextToken: "..." } }
      if (n.token && typeof n.token === 'object') {
        const t = n.token as Record<string, unknown>
        for (const key of directKeys) {
          if (typeof t[key] === 'string' && t[key].trim()) return String(t[key]).trim()
        }
      }
    }
  }

  // Last resort: find a JWT-like or long opaque token string
  const strings = digStrings(obj)
  const jwt = strings.find((s) => /^[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+$/.test(s.value))
  if (jwt) return jwt.value
  const named = strings.find((s) => /token/i.test(s.path) && s.value.length > 20)
  if (named) return named.value
  return ''
}

export function extractSubscriptions(payload: unknown): Array<{ ownerKey: string; name: string }> {
  const candidates: unknown[] = []
  if (Array.isArray(payload)) candidates.push(...payload)
  if (payload && typeof payload === 'object') {
    const obj = payload as Record<string, unknown>
    for (const key of ['data', 'Data', 'subscriptions', 'Subscriptions', 'items', 'result', 'Result']) {
      if (Array.isArray(obj[key])) candidates.push(...(obj[key] as unknown[]))
      if (obj[key] && typeof obj[key] === 'object' && !Array.isArray(obj[key])) {
        const nested = obj[key] as Record<string, unknown>
        for (const k2 of ['data', 'Data', 'subscriptions', 'items']) {
          if (Array.isArray(nested[k2])) candidates.push(...(nested[k2] as unknown[]))
        }
      }
    }
  }

  return candidates
    .map((item) => {
      const row = item as Record<string, unknown>
      const ownerKey = String(
        row.ownerKey ||
          row.owner_key ||
          row.OwnerKey ||
          row.WAKEED_SCHEMA ||
          row.wakeedSchema ||
          row.schema ||
          row.Schema ||
          row.subscriberKey ||
          row.SubscriberKey ||
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
          row.SubscriptionName ||
          row.displayName ||
          row.DisplayName ||
          row.title ||
          row.Title ||
          ownerKey,
      )
      return { ownerKey, name }
    })
    .filter((x) => x.ownerKey)
}
