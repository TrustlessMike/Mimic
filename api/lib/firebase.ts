type FirestoreValue =
  | { stringValue: string }
  | { integerValue: string }
  | { doubleValue: number }
  | { booleanValue: boolean }
  | { timestampValue: string }
  | { mapValue: { fields?: Record<string, FirestoreValue> } }
  | { arrayValue: { values?: FirestoreValue[] } }
  | { nullValue: null };

type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id?: string;
};

type StructuredQuery = {
  from: Array<{ collectionId: string }>;
  where?: {
    fieldFilter: {
      field: { fieldPath: string };
      op: "EQUAL";
      value: FirestoreValue;
    };
  };
  orderBy?: Array<{
    field: { fieldPath: string };
    direction: "ASCENDING" | "DESCENDING";
  }>;
  limit?: number;
};

let tokenCache: { token: string; expiresAt: number } | null = null;

function parseServiceAccount(value: string): ServiceAccount {
  try {
    return JSON.parse(value);
  } catch {
    const normalized = value.replace(
      /"private_key"\s*:\s*"([\s\S]*?)"\s*,\s*"client_email"/,
      (_match, privateKey) => `"private_key":${JSON.stringify(privateKey)},"client_email"`
    );

    return JSON.parse(normalized);
  }
}

function getServiceAccount(): ServiceAccount {
  if (!process.env.FIREBASE_SERVICE_ACCOUNT) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT not configured");
  }

  return parseServiceAccount(process.env.FIREBASE_SERVICE_ACCOUNT);
}

function base64Url(input: string | ArrayBuffer): string {
  const bytes =
    typeof input === "string"
      ? new TextEncoder().encode(input)
      : new Uint8Array(input);

  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }

  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);

  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }

  return bytes.buffer;
}

async function getAccessToken(): Promise<string> {
  if (tokenCache && tokenCache.expiresAt > Date.now() + 60_000) {
    return tokenCache.token;
  }

  const serviceAccount = getServiceAccount();
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/datastore",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };
  const unsigned = `${base64Url(JSON.stringify(header))}.${base64Url(JSON.stringify(claim))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    new TextEncoder().encode(unsigned)
  );
  const assertion = `${unsigned}.${base64Url(signature)}`;
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!response.ok) {
    throw new Error(`Failed to obtain Firestore access token: ${response.status}`);
  }

  const data = (await response.json()) as { access_token: string; expires_in: number };
  tokenCache = {
    token: data.access_token,
    expiresAt: Date.now() + data.expires_in * 1000,
  };

  return tokenCache.token;
}

function encodeValue(value: unknown): FirestoreValue {
  if (value === null || value === undefined) {
    return { nullValue: null };
  }
  if (typeof value === "boolean") {
    return { booleanValue: value };
  }
  if (typeof value === "number") {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }

  return { stringValue: String(value) };
}

function decodeValue(value?: FirestoreValue): any {
  if (!value) return undefined;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("timestampValue" in value) {
    return { toDate: () => new Date(value.timestampValue) };
  }
  if ("arrayValue" in value) {
    return (value.arrayValue.values || []).map(decodeValue);
  }
  if ("mapValue" in value) {
    return decodeFields(value.mapValue.fields || {});
  }
  return null;
}

function decodeFields(fields: Record<string, FirestoreValue>): Record<string, any> {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, decodeValue(value)])
  );
}

class Query {
  private filters: Array<{ field: string; value: unknown }> = [];
  private sort?: { field: string; direction: "ASCENDING" | "DESCENDING" };
  private rowLimit?: number;

  constructor(private collectionId: string) {}

  where(field: string, operator: string, value: unknown): Query {
    if (operator !== "==") {
      throw new Error(`Unsupported Firestore operator: ${operator}`);
    }

    this.filters.push({ field, value });
    return this;
  }

  orderBy(field: string, direction: "asc" | "desc" = "asc"): Query {
    this.sort = {
      field,
      direction: direction === "desc" ? "DESCENDING" : "ASCENDING",
    };
    return this;
  }

  limit(limit: number): Query {
    this.rowLimit = limit;
    return this;
  }

  count() {
    return {
      get: async () => {
        const token = await getAccessToken();
        const response = await fetch(firestoreUrl(":runAggregationQuery"), {
          method: "POST",
          headers: {
            authorization: `Bearer ${token}`,
            "content-type": "application/json",
          },
          body: JSON.stringify({
            structuredAggregationQuery: {
              structuredQuery: this.toStructuredQuery(false),
              aggregations: [{ alias: "count", count: {} }],
            },
          }),
        });

        if (!response.ok) {
          throw new Error(`Firestore count failed: ${response.status}`);
        }

        const rows = (await response.json()) as Array<{
          result?: { aggregateFields?: { count?: { integerValue?: string } } };
        }>;
        const count = Number(rows[0]?.result?.aggregateFields?.count?.integerValue || 0);

        return { data: () => ({ count }) };
      },
    };
  }

  async get() {
    const token = await getAccessToken();
    const response = await fetch(firestoreUrl(":runQuery"), {
      method: "POST",
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ structuredQuery: this.toStructuredQuery(true) }),
    });

    if (!response.ok) {
      throw new Error(`Firestore query failed: ${response.status}`);
    }

    const rows = (await response.json()) as Array<{
      document?: { name: string; fields?: Record<string, FirestoreValue> };
    }>;
    const docs = rows
      .filter((row) => row.document)
      .map((row) => {
        const document = row.document!;
        return {
          id: document.name.split("/").pop() || "",
          data: () => decodeFields(document.fields || {}),
        };
      });

    return { docs };
  }

  private toStructuredQuery(includeLimit: boolean): StructuredQuery {
    const query: StructuredQuery = {
      from: [{ collectionId: this.collectionId }],
    };

    if (this.filters.length > 0) {
      const [filter] = this.filters;
      query.where = {
        fieldFilter: {
          field: { fieldPath: filter.field },
          op: "EQUAL",
          value: encodeValue(filter.value),
        },
      };
    }

    if (this.sort) {
      query.orderBy = [
        {
          field: { fieldPath: this.sort.field },
          direction: this.sort.direction,
        },
      ];
    }

    if (includeLimit && this.rowLimit) {
      query.limit = this.rowLimit;
    }

    return query;
  }
}

function firestoreUrl(suffix: string): string {
  const projectId = getServiceAccount().project_id || "wickett-13423";
  return `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents${suffix}`;
}

export const db = {
  collection(collectionId: string) {
    return new Query(collectionId);
  },
};
