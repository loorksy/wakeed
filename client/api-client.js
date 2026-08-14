(function (global) {
  const WP = global.WakeedPlatform;
  const platformState = WP.platformState;

  function mapLedgerRow(row) {
    return {
      id: row.id,
      ownerKey: row.owner_key || row.ownerKey || "",
      createdAt: row.created_at || row.createdAt,
      entryDate: row.entry_date || row.entryDate,
      journalNumber: row.journal_number || row.journalNumber,
      journalId: row.journal_id || row.journalId,
      kind: row.kind,
      name: row.name,
      amount: row.amount,
      debitAccount: row.debit_account || row.debitAccount,
      debitAccountName: row.debit_account_name || row.debitAccountName,
      creditAccount: row.credit_account || row.creditAccount,
      creditAccountName: row.credit_account_name || row.creditAccountName,
      notes: row.notes,
      statement: row.statement,
    };
  }

  function formatProxyError(data) {
    if (!data) return "خطأ في وكيد";
    if (typeof data === "string") return data;
    if (data.message) return data.message;
    if (data.Message) return data.Message;
    try {
      return JSON.stringify(data).slice(0, 400);
    } catch (_) {
      return "خطأ في وكيد";
    }
  }

  async function syncLoadAll() {
    const json = await WP.platformFetch("/api/user-data");
    const data = json.data !== undefined ? json.data : json;
    const settings = data.settings || {};
    const theme = data.theme || "dark";
    if (data.wakeed) {
      platformState.ownerKey = data.wakeed.ownerKey || "";
      platformState.username = data.wakeed.username || "";
      platformState.server = data.wakeed.server || "server1.wakeed.app";
      platformState.buildNumber = data.wakeed.buildNumber || "3996";
      platformState.userDisplayName = data.wakeed.userDisplayName || "";
      platformState.subscriptions = data.wakeed.subscriptions || [];
      platformState.wakeedToken = data.wakeed.hasToken ? "server-held" : "";
    }
    const ledgerJson = await WP.platformFetch("/api/ledger");
    const ledgerData = ledgerJson.data !== undefined ? ledgerJson.data : ledgerJson;
    const ledger = (ledgerData.rows || []).map(mapLedgerRow);
    return { settings: settings, theme: theme, ledger: ledger };
  }

  async function syncSaveSettings(settings, theme) {
    await WP.platformFetch("/api/user-data", {
      method: "PUT",
      body: JSON.stringify({ settings: settings, theme: theme }),
    });
  }

  async function syncSaveWakeed(partial) {
    const wakeed = {
      ownerKey: partial.ownerKey !== undefined ? partial.ownerKey : platformState.ownerKey,
      username: partial.username !== undefined ? partial.username : platformState.username,
      server: partial.server !== undefined ? partial.server : platformState.server,
      buildNumber: partial.buildNumber !== undefined ? partial.buildNumber : platformState.buildNumber,
      userDisplayName:
        partial.userDisplayName !== undefined ? partial.userDisplayName : platformState.userDisplayName,
      subscriptions:
        partial.subscriptions !== undefined ? partial.subscriptions : platformState.subscriptions,
    };
    if (partial.token !== undefined) wakeed.token = partial.token;
    await WP.platformFetch("/api/user-data", {
      method: "PUT",
      body: JSON.stringify({ wakeed: wakeed }),
    });
  }

  async function syncAppendLedger(entries) {
    await WP.platformFetch("/api/ledger", {
      method: "POST",
      body: JSON.stringify({ entries: entries }),
    });
  }

  async function syncGetLedger(ownerKey) {
    const q = ownerKey ? "?ownerKey=" + encodeURIComponent(ownerKey) : "";
    const json = await WP.platformFetch("/api/ledger" + q);
    const data = json.data !== undefined ? json.data : json;
    return (data.rows || []).map(mapLedgerRow);
  }

  async function wakeedLogin(username, password, extra) {
    extra = extra || {};
    const json = await WP.platformFetch("/api/wakeed/login", {
      method: "POST",
      body: JSON.stringify({
        username: username,
        password: password,
        server: extra.server || platformState.server,
        buildNumber: extra.buildNumber || platformState.buildNumber,
        ownerKey: extra.ownerKey || platformState.ownerKey,
        deviceName: extra.deviceName || "WakeedMobile",
      }),
    });
    const data = json.data !== undefined ? json.data : json;
    platformState.userDisplayName = data.userDisplayName || "";
    platformState.subscriptions = data.subscriptions || [];
    platformState.ownerKey = data.ownerKey || platformState.ownerKey;
    platformState.wakeedToken = "server-held";
    return data;
  }

  async function wakeedLogout() {
    await WP.platformFetch("/api/wakeed/logout", { method: "POST" });
    platformState.wakeedToken = "";
  }

  async function wakeedProxy(method, path, body, options) {
    options = options || {};
    const splitIndex = path.indexOf("?");
    const apiPath = splitIndex >= 0 ? path.slice(0, splitIndex) : path;
    const query = {};
    if (splitIndex >= 0) {
      new URLSearchParams(path.slice(splitIndex + 1)).forEach(function (v, k) {
        query[k] = v;
      });
    }
    const json = await WP.platformFetch("/api/wakeed/proxy", {
      method: "POST",
      body: JSON.stringify({
        method: method,
        path: apiPath,
        query: query,
        body: body === undefined ? undefined : body,
        asForm: Boolean(options.asForm),
        ownerKey: platformState.ownerKey,
        server: platformState.server,
        buildNumber: platformState.buildNumber,
      }),
    });
    const payload = json.data !== undefined ? json : json;
    if (payload.ok === false) {
      throw new Error(formatProxyError(payload.data));
    }
    return payload.data !== undefined ? payload.data : payload;
  }

  global.WakeedApi = {
    syncLoadAll: syncLoadAll,
    syncSaveSettings: syncSaveSettings,
    syncSaveWakeed: syncSaveWakeed,
    syncAppendLedger: syncAppendLedger,
    syncGetLedger: syncGetLedger,
    wakeedLogin: wakeedLogin,
    wakeedLogout: wakeedLogout,
    wakeedProxy: wakeedProxy,
    platformState: platformState,
  };
})(window);
