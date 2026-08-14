import { useEffect, useMemo, useState } from 'react'
import {
  extractSubscriptions,
  extractToken,
  fetchAccounts,
  fetchCostCenters,
  fetchCurrencies,
  fetchJournalTypes,
  fetchSubscriptions,
  importRemittances,
  loadSession,
  login,
  saveSession,
  type LookupItem,
  type Session,
} from './api'
import {
  COLUMN_LABELS,
  guessMapping,
  mapRowsToObjects,
  parsePaste,
  SAMPLE_PASTE,
  type ColumnKey,
} from './paste'

type ImportResult = {
  index: number
  ok: boolean
  message: string
}

function Brand() {
  return (
    <div className="brand-mark">
      <img src="/wakeed.svg" alt="Wakeed" />
      <strong>وكيد</strong>
    </div>
  )
}

function LoginPage({
  onLoggedIn,
}: {
  onLoggedIn: (session: Session) => void
}) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [subs, setSubs] = useState<Array<{ ownerKey: string; name: string }>>([])
  const [token, setToken] = useState('')
  const [ownerKey, setOwnerKey] = useState('')
  const [manualOwnerKey, setManualOwnerKey] = useState('')

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)
    setError('')
    try {
      const res = await login(email.trim(), password)
      const t = extractToken(res.data)
      if (!t) throw new Error('لم يتم استلام رمز الدخول من وكيد')
      setToken(t)
      const subRes = await fetchSubscriptions(t)
      const list = extractSubscriptions(subRes.data)
      setSubs(list)
      if (list.length === 1) setOwnerKey(list[0].ownerKey)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'فشل تسجيل الدخول')
    } finally {
      setLoading(false)
    }
  }

  function continueWithOwner(key: string) {
    if (!token || !key) {
      setError('اختر الاشتراك / أدخل المفتاح')
      return
    }
    const session: Session = {
      token,
      ownerKey: key,
      email: email.trim(),
    }
    saveSession(session)
    onLoggedIn(session)
  }

  return (
    <div className="app-shell hero-login">
      <div className="hero-copy">
        <Brand />
        <h1>إدخال دفعي لسندات الحوالات</h1>
        <p>
          الصق بيانات الحوالات من Excel دفعة واحدة، راجعها، ثم أرسلها مباشرة إلى قسم سندات
          الحوالات في وكيد عبر الـ API.
        </p>
      </div>

      <div className="panel" style={{ maxWidth: 460, width: '100%', justifySelf: 'end' }}>
        <h2>تسجيل الدخول إلى وكيد</h2>
        {!token ? (
          <form onSubmit={handleLogin}>
            <div className="field">
              <label htmlFor="email">البريد الإلكتروني</label>
              <input
                id="email"
                type="email"
                autoComplete="username"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
            </div>
            <div className="field">
              <label htmlFor="password">كلمة المرور</label>
              <input
                id="password"
                type="password"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
            </div>
            {error ? <p className="error">{error}</p> : null}
            <div className="btn-row" style={{ marginTop: '1rem' }}>
              <button className="btn btn-primary" type="submit" disabled={loading}>
                {loading ? 'جاري الدخول...' : 'دخول'}
              </button>
            </div>
          </form>
        ) : (
          <div>
            <p className="hint">اختر الاشتراك (owner-key) لإرسال سندات الحوالات.</p>
            {subs.length ? (
              <div className="field">
                <label htmlFor="owner">الاشتراك</label>
                <select
                  id="owner"
                  value={ownerKey}
                  onChange={(e) => setOwnerKey(e.target.value)}
                >
                  <option value="">— اختر —</option>
                  {subs.map((s) => (
                    <option key={s.ownerKey} value={s.ownerKey}>
                      {s.name}
                    </option>
                  ))}
                </select>
              </div>
            ) : (
              <div className="field">
                <label htmlFor="manualOwner">أدخل owner-key يدوياً</label>
                <input
                  id="manualOwner"
                  value={manualOwnerKey}
                  onChange={(e) => setManualOwnerKey(e.target.value)}
                  placeholder="مفتاح الاشتراك"
                />
              </div>
            )}
            {error ? <p className="error">{error}</p> : null}
            <div className="btn-row">
              <button
                className="btn btn-primary"
                type="button"
                onClick={() => continueWithOwner(ownerKey || manualOwnerKey.trim())}
              >
                متابعة
              </button>
              <button
                className="btn btn-ghost"
                type="button"
                onClick={() => {
                  setToken('')
                  setSubs([])
                  setOwnerKey('')
                }}
              >
                رجوع
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

function RemittanceImport({
  session,
  onLogout,
}: {
  session: Session
  onLogout: () => void
}) {
  const [paste, setPaste] = useState('')
  const [headers, setHeaders] = useState<string[]>([])
  const [rawRows, setRawRows] = useState<string[][]>([])
  const [mapping, setMapping] = useState<ColumnKey[]>([])
  const [journalTypes, setJournalTypes] = useState<LookupItem[]>([])
  const [currencies, setCurrencies] = useState<LookupItem[]>([])
  const [costCenters, setCostCenters] = useState<LookupItem[]>([])
  const [accountsHint, setAccountsHint] = useState<LookupItem[]>([])
  const [journalTypeId, setJournalTypeId] = useState('')
  const [defaultAccountId, setDefaultAccountId] = useState('')
  const [defaultCurrencyId, setDefaultCurrencyId] = useState('')
  const [defaultCostCenterId, setDefaultCostCenterId] = useState('')
  const [defaultRate, setDefaultRate] = useState('1')
  const [loadingLookups, setLoadingLookups] = useState(true)
  const [lookupError, setLookupError] = useState('')
  const [importing, setImporting] = useState(false)
  const [results, setResults] = useState<ImportResult[]>([])
  const [summary, setSummary] = useState<{ ok: number; fail: number } | null>(null)

  useEffect(() => {
    let cancelled = false
    ;(async () => {
      setLoadingLookups(true)
      setLookupError('')
      try {
        const [jt, cur, cc, acc] = await Promise.all([
          fetchJournalTypes(session),
          fetchCurrencies(session),
          fetchCostCenters(session),
          fetchAccounts(session),
        ])
        if (cancelled) return
        setJournalTypes(jt.data || [])
        setCurrencies(cur.data || [])
        setCostCenters(cc.data || [])
        setAccountsHint(acc.data || [])
        if (jt.data?.length === 1) setJournalTypeId(jt.data[0].id)
        // Prefer remittance-like journal types if named
        const remittance = (jt.data || []).find((x) =>
          /حوال|remit|transfer|قبض|دفع/i.test(`${x.name}`),
        )
        if (remittance) setJournalTypeId(remittance.id)
        if (cur.data?.length === 1) setDefaultCurrencyId(cur.data[0].id)
      } catch (err) {
        if (!cancelled) {
          setLookupError(err instanceof Error ? err.message : 'تعذر تحميل البيانات المرجعية')
        }
      } finally {
        if (!cancelled) setLoadingLookups(false)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [session])

  useEffect(() => {
    const selected = journalTypes.find((j) => j.id === journalTypeId)
    if (selected?.mainAccountId && !defaultAccountId) {
      setDefaultAccountId(selected.mainAccountId)
    }
    if (selected?.costCenterId && !defaultCostCenterId) {
      setDefaultCostCenterId(selected.costCenterId)
    }
  }, [journalTypeId, journalTypes, defaultAccountId, defaultCostCenterId])

  const mappedRows = useMemo(
    () => mapRowsToObjects(headers, rawRows, mapping),
    [headers, rawRows, mapping],
  )

  function handleParse() {
    const parsed = parsePaste(paste)
    setHeaders(parsed.headers)
    setRawRows(parsed.rows)
    setMapping(guessMapping(parsed.headers))
    setResults([])
    setSummary(null)
  }

  async function handleImport() {
    if (!mappedRows.length) return
    setImporting(true)
    setResults([])
    setSummary(null)
    try {
      const res = await importRemittances(session, mappedRows, {
        JournalTypeId: journalTypeId,
        AccountID: defaultAccountId || undefined,
        CurrencyID: defaultCurrencyId || undefined,
        CostCenterId: defaultCostCenterId || undefined,
        VoucherRate: Number(defaultRate) || 1,
      })
      setResults(res.results || [])
      setSummary({
        ok: res.successCount ?? 0,
        fail: res.failCount ?? (res.results || []).filter((r) => !r.ok).length,
      })
      if (res.message && res.failCount) {
        setResults((prev) => [
          ...prev,
          { index: -1, ok: false, message: res.message || 'اكتمل مع أخطاء' },
        ])
      }
    } catch (err) {
      setSummary({ ok: 0, fail: mappedRows.length })
      setResults([
        {
          index: -1,
          ok: false,
          message: err instanceof Error ? err.message : 'فشل الاستيراد',
        },
      ])
    } finally {
      setImporting(false)
    }
  }

  return (
    <div className="app-shell">
      <div className="topbar">
        <Brand />
        <div className="btn-row">
          <span className="muted" style={{ alignSelf: 'center' }}>
            {session.email}
          </span>
          <button className="btn btn-ghost" type="button" onClick={onLogout}>
            خروج
          </button>
        </div>
      </div>

      <div className="panel" style={{ marginBottom: '1rem' }}>
        <h2>إعدادات سند الحوالة</h2>
        <p className="hint">
          القيم الافتراضية تُستخدم لكل الصفوف إذا لم تكن موجودة في البيانات الملصقة. نوع
          السند يجب أن يكون من أنواع سندات الحوالات في وكيد.
        </p>
        {loadingLookups ? <p className="muted">جاري تحميل الأنواع والعملات...</p> : null}
        {lookupError ? <p className="error">{lookupError}</p> : null}
        <div className="map-grid">
          <div className="field">
            <label>نوع السند</label>
            <select value={journalTypeId} onChange={(e) => setJournalTypeId(e.target.value)}>
              <option value="">— اختر —</option>
              {journalTypes.map((j) => (
                <option key={j.id} value={j.id}>
                  {j.name}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label>الحساب الرئيسي الافتراضي</label>
            <select
              value={defaultAccountId}
              onChange={(e) => setDefaultAccountId(e.target.value)}
            >
              <option value="">— من الصف / اختياري —</option>
              {accountsHint.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.code ? `${a.code} — ` : ''}
                  {a.name}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label>العملة الافتراضية</label>
            <select
              value={defaultCurrencyId}
              onChange={(e) => setDefaultCurrencyId(e.target.value)}
            >
              <option value="">— من الصف / اختياري —</option>
              {currencies.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.code ? `${c.code} — ` : ''}
                  {c.name}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label>مركز التكلفة الافتراضي</label>
            <select
              value={defaultCostCenterId}
              onChange={(e) => setDefaultCostCenterId(e.target.value)}
            >
              <option value="">— اختياري —</option>
              {costCenters.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.code ? `${c.code} — ` : ''}
                  {c.name}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label>سعر الصرف الافتراضي</label>
            <input value={defaultRate} onChange={(e) => setDefaultRate(e.target.value)} />
          </div>
        </div>
      </div>

      <div className="grid-2">
        <div className="panel">
          <h2>لصق البيانات</h2>
          <p className="hint">
            انسخ الصفوف من Excel (مع صف العناوين) والصقها هنا. يتم التعرف تلقائياً على
            الفواصل Tab / فاصلة / فاصلة منقوطة.
          </p>
          <div className="field">
            <label htmlFor="paste">البيانات</label>
            <textarea
              id="paste"
              value={paste}
              onChange={(e) => setPaste(e.target.value)}
              placeholder={SAMPLE_PASTE}
            />
          </div>
          <div className="btn-row">
            <button className="btn btn-primary" type="button" onClick={handleParse} disabled={!paste.trim()}>
              تحليل البيانات
            </button>
            <button
              className="btn btn-ghost"
              type="button"
              onClick={() => setPaste(SAMPLE_PASTE)}
            >
              مثال توضيحي
            </button>
          </div>
          <div className="sample">{SAMPLE_PASTE}</div>
        </div>

        <div className="panel">
          <h2>ربط الأعمدة</h2>
          {!headers.length ? (
            <p className="muted">بعد اللصق والتحليل ستظهر أعمدة الربط هنا.</p>
          ) : (
            <div className="map-grid">
              {headers.map((header, idx) => (
                <div className="field" key={`${header}-${idx}`}>
                  <label>{header || `عمود ${idx + 1}`}</label>
                  <select
                    value={mapping[idx] || 'ignore'}
                    onChange={(e) => {
                      const next = [...mapping]
                      next[idx] = e.target.value as ColumnKey
                      setMapping(next)
                    }}
                  >
                    {(Object.keys(COLUMN_LABELS) as ColumnKey[]).map((key) => (
                      <option key={key} value={key}>
                        {COLUMN_LABELS[key]}
                      </option>
                    ))}
                  </select>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="panel" style={{ marginTop: '1rem' }}>
        <h2>معاينة سندات الحوالات</h2>
        <div className="stats">
          <div className="stat">
            <strong>{mappedRows.length}</strong>
            <span className="muted">صف جاهز</span>
          </div>
          {summary ? (
            <>
              <div className="stat">
                <strong className="ok">{summary.ok}</strong>
                <span className="muted">نجح</span>
              </div>
              <div className="stat">
                <strong className="error">{summary.fail}</strong>
                <span className="muted">فشل</span>
              </div>
            </>
          ) : null}
        </div>

        {!mappedRows.length ? (
          <p className="muted">لا توجد صفوف للمعاينة بعد.</p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>#</th>
                  <th>التاريخ</th>
                  <th>المرجع</th>
                  <th>الحساب الرئيسي</th>
                  <th>حساب الطرف</th>
                  <th>المبلغ</th>
                  <th>العملة</th>
                  <th>البيان</th>
                  <th>النتيجة</th>
                </tr>
              </thead>
              <tbody>
                {mappedRows.map((row, idx) => {
                  const result = results.find((r) => r.index === idx)
                  return (
                    <tr key={idx}>
                      <td>{idx + 1}</td>
                      <td>{row.Date || '—'}</td>
                      <td>{row.OffLineNumber || '—'}</td>
                      <td>{row.AccountID || defaultAccountId || '—'}</td>
                      <td>{row.DetailAccountId || '—'}</td>
                      <td>{row.Amount || '—'}</td>
                      <td>{row.CurrencyID || defaultCurrencyId || '—'}</td>
                      <td>{row.Notes || '—'}</td>
                      <td>
                        {result ? (
                          <span className={`status-pill ${result.ok ? 'ok' : 'fail'}`}>
                            {result.message}
                          </span>
                        ) : (
                          <span className="muted">بانتظار الإرسال</span>
                        )}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}

        <div className="btn-row" style={{ marginTop: '1rem' }}>
          <button
            className="btn btn-primary"
            type="button"
            disabled={!mappedRows.length || !journalTypeId || importing}
            onClick={handleImport}
          >
            {importing ? 'جاري الإرسال إلى وكيد...' : 'إرسال سندات الحوالات'}
          </button>
        </div>
        {!journalTypeId ? (
          <p className="error">اختر نوع سند الحوالة قبل الإرسال.</p>
        ) : null}
        {results.some((r) => r.index === -1) ? (
          <p className="error">{results.find((r) => r.index === -1)?.message}</p>
        ) : null}
      </div>
    </div>
  )
}

export default function App() {
  const [session, setSession] = useState<Session | null>(() => loadSession())

  if (!session) {
    return <LoginPage onLoggedIn={setSession} />
  }

  return (
    <RemittanceImport
      session={session}
      onLogout={() => {
        saveSession(null)
        setSession(null)
      }}
    />
  )
}
