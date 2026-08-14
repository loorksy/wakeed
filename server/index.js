import express from 'express';
import cors from 'cors';
import FormData from 'form-data';
import fetch from 'node-fetch';

const app = express();
const PORT = process.env.PORT || 8787;
const WAKEED_BASE = process.env.WAKEED_BASE_URL || 'https://server1.wakeed.app';
const BUILD_NUMBER = process.env.WAKEED_BUILD_NUMBER || '12000';

app.use(cors());
app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: true }));

function wakeedHeaders(req, extra = {}) {
  const token =
    req.headers['x-wakeed-token'] ||
    (typeof req.headers.authorization === 'string'
      ? req.headers.authorization.replace(/^Bearer\s+/i, '')
      : '');
  const ownerKey = req.headers['x-owner-key'] || req.headers['owner-key'];
  const headers = {
    Accept: 'application/json',
    'build-number': BUILD_NUMBER,
    ...extra,
  };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
    headers.authentication = `Bearer ${token}`;
  }
  if (ownerKey) headers['owner-key'] = ownerKey;
  return headers;
}

async function parseWakeedResponse(res) {
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = { raw: text };
  }
  return { ok: res.ok, status: res.status, data };
}

function appendObjectToForm(form, obj, prefix = '') {
  Object.entries(obj || {}).forEach(([key, value]) => {
    if (value === undefined || value === null || value === '') return;
    const field = prefix ? `${prefix}.${key}` : key;
    if (Array.isArray(value)) {
      value.forEach((item, index) => {
        if (item && typeof item === 'object') {
          appendObjectToForm(form, item, `${field}[${index}]`);
        } else if (item !== undefined && item !== null && item !== '') {
          form.append(`${field}[${index}]`, String(item));
        }
      });
    } else if (typeof value === 'object') {
      appendObjectToForm(form, value, field);
    } else if (typeof value === 'boolean') {
      form.append(field, value ? 'true' : 'false');
    } else {
      form.append(field, String(value));
    }
  });
}

function unwrapList(payload) {
  if (Array.isArray(payload)) return payload;
  if (!payload || typeof payload !== 'object') return [];
  for (const key of ['data', 'Data', 'items', 'Items', 'result', 'Result']) {
    if (Array.isArray(payload[key])) return payload[key];
  }
  // nested success wrappers
  if (payload.data && typeof payload.data === 'object') {
    return unwrapList(payload.data);
  }
  return [];
}

function pickId(item) {
  return item?.Id || item?.id || item?.Key || item?.key || '';
}

function pickName(item) {
  return (
    item?.DisplayName ||
    item?.displayName ||
    item?.FullName ||
    item?.fullName ||
    item?.Name ||
    item?.name ||
    item?.Value ||
    item?.value ||
    item?.Code ||
    item?.code ||
    pickId(item)
  );
}

async function wakeedGet(req, path) {
  const response = await fetch(`${WAKEED_BASE}${path}`, {
    headers: wakeedHeaders(req),
  });
  return parseWakeedResponse(response);
}

app.get('/api/health', (_req, res) => {
  res.json({ ok: true, service: 'wakeed-remittance-import', wakeedBase: WAKEED_BASE });
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password, deviceName = 'Wakeed Remittance Import' } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'البريد وكلمة المرور مطلوبان' });
    }

    const body = new URLSearchParams({
      email,
      password,
      device_name: deviceName,
    });

    const response = await fetch(`${WAKEED_BASE}/user-api/login-by-email?app_locale=ar`, {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
        'build-number': BUILD_NUMBER,
      },
      body,
    });

    const result = await parseWakeedResponse(response);
    if (!result.ok) {
      return res.status(result.status).json({
        success: false,
        message: result.data?.message || 'فشل تسجيل الدخول',
        data: result.data,
      });
    }

    res.json({ success: true, data: result.data?.data ?? result.data });
  } catch (error) {
    console.error('login error', error);
    res.status(500).json({ success: false, message: error.message || 'خطأ في الاتصال بوكيد' });
  }
});

app.get('/api/auth/subscriptions', async (req, res) => {
  try {
    const result = await wakeedGet(req, '/user-api/my-subscriptions?app_locale=ar');
    if (!result.ok) {
      return res.status(result.status).json({
        success: false,
        message: result.data?.message || 'تعذر جلب الاشتراكات',
        data: result.data,
      });
    }
    res.json({ success: true, data: result.data?.data ?? result.data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/auth/profile', async (req, res) => {
  try {
    const result = await wakeedGet(req, '/user-api/profile?app_locale=ar');
    res.status(result.status).json({
      success: result.ok,
      data: result.data?.data ?? result.data,
      message: result.ok ? undefined : result.data?.message,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/lookups/journal-types', async (req, res) => {
  try {
    let result = await wakeedGet(req, '/api/JournalVoucher/GetJournalTypes');
    if (!result.ok) {
      result = await wakeedGet(req, '/api/JournalType');
    }
    const list = unwrapList(result.data?.data ?? result.data).map((item) => ({
      id: pickId(item),
      name: pickName(item),
      mainAccountId: item.MainVoucherAccountId || item.mainVoucherAccountId || '',
      costCenterId: item.CostCenterId || item.costCenterId || '',
      raw: item,
    }));
    res.status(result.status).json({
      success: result.ok,
      data: list,
      message: result.ok ? undefined : result.data?.message || 'تعذر جلب أنواع السندات',
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/lookups/currencies', async (req, res) => {
  try {
    const result = await wakeedGet(req, '/api/Currency');
    const list = unwrapList(result.data?.data ?? result.data).map((item) => ({
      id: pickId(item),
      name: pickName(item),
      code: item.Code || item.code || '',
      raw: item,
    }));
    res.status(result.status).json({
      success: result.ok,
      data: list,
      message: result.ok ? undefined : result.data?.message,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/lookups/cost-centers', async (req, res) => {
  try {
    const result = await wakeedGet(req, '/api/CostCenter');
    const list = unwrapList(result.data?.data ?? result.data).map((item) => ({
      id: pickId(item),
      name: pickName(item),
      code: item.Code || item.code || '',
      raw: item,
    }));
    res.status(result.status).json({
      success: result.ok,
      data: list,
      message: result.ok ? undefined : result.data?.message,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/lookups/accounts', async (req, res) => {
  try {
    const q = (req.query.q || '').toString().trim();
    let result;
    if (q) {
      result = await wakeedGet(req, `/api/NormalAccount/GetByCode?code=${encodeURIComponent(q)}`);
      const payload = result.data?.data ?? result.data;
      const list = payload
        ? [
            {
              id: pickId(payload),
              name: pickName(payload),
              code: payload.Code || payload.code || q,
              raw: payload,
            },
          ].filter((x) => x.id)
        : [];
      return res.status(result.ok || list.length ? 200 : result.status).json({
        success: Boolean(list.length || result.ok),
        data: list,
      });
    }

    result = await wakeedGet(req, '/api/NormalAccount');
    const list = unwrapList(result.data?.data ?? result.data)
      .slice(0, 500)
      .map((item) => ({
        id: pickId(item),
        name: pickName(item),
        code: item.Code || item.code || '',
        raw: item,
      }));
    res.status(result.status).json({
      success: result.ok,
      data: list,
      message: result.ok ? undefined : result.data?.message,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/remittances', async (req, res) => {
  try {
    const params = new URLSearchParams();
    [
      'normalAccountId',
      'costCenterId',
      'currencyId',
      'note',
      'journalEntryNumber',
      'fromDate',
      'toDate',
      'offset',
      'limit',
      'userId',
    ].forEach((key) => {
      if (req.query[key] !== undefined && req.query[key] !== '') {
        params.set(key, String(req.query[key]));
      }
    });
    const result = await wakeedGet(req, `/api/JournalEntry/RemittanceIndex?${params.toString()}`);
    res.status(result.status).json({
      success: result.ok,
      data: result.data?.data ?? result.data,
      message: result.ok ? undefined : result.data?.message,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

function toNumber(value, fallback = 0) {
  if (value === undefined || value === null || value === '') return fallback;
  const n = Number(String(value).replace(/,/g, ''));
  return Number.isFinite(n) ? n : fallback;
}

function toIsoDate(value) {
  if (!value) return new Date().toISOString();
  const raw = String(value).trim();
  // dd/mm/yyyy or dd-mm-yyyy
  const m = raw.match(/^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})$/);
  if (m) {
    const day = Number(m[1]);
    const month = Number(m[2]);
    let year = Number(m[3]);
    if (year < 100) year += 2000;
    return new Date(Date.UTC(year, month - 1, day)).toISOString();
  }
  const d = new Date(raw);
  if (!Number.isNaN(d.getTime())) return d.toISOString();
  return new Date().toISOString();
}

function buildVoucherPayload(row, defaults = {}) {
  const amount = toNumber(row.Amount ?? row.amount ?? row.Debit ?? row.Credit, 0);
  const mainAccountId = row.AccountID || row.MainAccountId || defaults.AccountID || '';
  const detailAccountId =
    row.DetailAccountId || row.CorrespondentAccountId || row.AgentAccountId || row.ToAccountId || '';
  const currencyId = row.CurrencyID || row.CurrencyId || defaults.CurrencyID || '';
  const journalTypeId = row.JournalTypeId || defaults.JournalTypeId || '';
  const costCenterId = row.CostCenterId || defaults.CostCenterId || undefined;
  const rate = toNumber(row.VoucherRate ?? row.Rate ?? row.CurrencyRate, defaults.VoucherRate ?? 1);
  const notes = row.Notes || row.Description || row.Statement || '';
  const detailNotes = row.DetailNotes || notes;
  const offline = row.OffLineNumber || row.Reference || row.RemittanceNumber || '';

  const detail = {
    AccountID: detailAccountId || undefined,
    NormalAccountId: detailAccountId || undefined,
    Amount: amount,
    Debit: toNumber(row.Debit, amount),
    Credit: toNumber(row.Credit, 0),
    Notes: detailNotes,
    CurrencyID: row.DetailCurrencyId || currencyId || undefined,
    CurrencyId: row.DetailCurrencyId || currencyId || undefined,
    EqualityRatio: toNumber(row.DetailRate ?? rate, 1),
    CostCenterId: row.DetailCostCenterId || costCenterId || undefined,
    CorrespondingAccountId: row.CorrespondingAccountId || mainAccountId || undefined,
  };

  return {
    AccountID: mainAccountId || undefined,
    CurrencyID: currencyId || undefined,
    VoucherRate: rate,
    Date: toIsoDate(row.Date || row.TheDate || defaults.Date),
    Notes: notes,
    OffLineNumber: offline,
    JournalTypeId: journalTypeId || undefined,
    CostCenterId: costCenterId || undefined,
    ScopeId: row.ScopeId || defaults.ScopeId || undefined,
    DiscountGivingAccountId: row.DiscountGivingAccountId || defaults.DiscountGivingAccountId || undefined,
    DiscountTakingAccountId: row.DiscountTakingAccountId || defaults.DiscountTakingAccountId || undefined,
    JournalVoucherDetails: [detail],
  };
}

app.post('/api/import/remittances', async (req, res) => {
  try {
    const rows = Array.isArray(req.body?.rows) ? req.body.rows : [];
    const defaults = req.body?.defaults || {};
    if (!rows.length) {
      return res.status(400).json({ success: false, message: 'لا توجد صفوف للاستيراد' });
    }
    if (!defaults.JournalTypeId && !rows.some((r) => r.JournalTypeId)) {
      return res.status(400).json({ success: false, message: 'نوع سند الحوالة مطلوب' });
    }

    const results = [];
    for (let i = 0; i < rows.length; i += 1) {
      const row = rows[i];
      const payload = buildVoucherPayload(row, defaults);

      if (!payload.JournalTypeId) {
        results.push({
          index: i,
          ok: false,
          payload: row,
          message: 'نوع السند مفقود',
        });
        continue;
      }
      if (!payload.AccountID) {
        results.push({
          index: i,
          ok: false,
          payload: row,
          message: 'الحساب الرئيسي مفقود',
        });
        continue;
      }
      if (!payload.JournalVoucherDetails?.[0]?.AccountID && !payload.JournalVoucherDetails?.[0]?.NormalAccountId) {
        results.push({
          index: i,
          ok: false,
          payload: row,
          message: 'حساب الطرف (التفاصيل) مفقود',
        });
        continue;
      }
      if (!toNumber(payload.JournalVoucherDetails?.[0]?.Amount, 0)) {
        results.push({
          index: i,
          ok: false,
          payload: row,
          message: 'المبلغ غير صالح',
        });
        continue;
      }

      const form = new FormData();
      appendObjectToForm(form, payload);

      try {
        const response = await fetch(`${WAKEED_BASE}/api/JournalVoucher`, {
          method: 'POST',
          headers: {
            ...wakeedHeaders(req),
            ...form.getHeaders(),
          },
          body: form,
        });
        const result = await parseWakeedResponse(response);
        results.push({
          index: i,
          ok: result.ok,
          status: result.status,
          payload: row,
          request: payload,
          response: result.data,
          message: result.ok ? 'تم إنشاء سند الحوالة' : result.data?.message || result.data?.title || 'فشل الإنشاء',
        });
      } catch (error) {
        results.push({
          index: i,
          ok: false,
          payload: row,
          message: error.message,
        });
      }
    }

    const successCount = results.filter((r) => r.ok).length;
    res.json({
      success: successCount === results.length,
      successCount,
      failCount: results.length - successCount,
      results,
    });
  } catch (error) {
    console.error('import remittances error', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Wakeed remittance import API on http://localhost:${PORT}`);
});
