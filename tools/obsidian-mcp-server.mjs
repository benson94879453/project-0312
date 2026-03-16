import fs from "node:fs";
import path from "node:path";
import http from "node:http";
import https from "node:https";
import { URL } from "node:url";

const SERVER_NAME = "obsidian-local-rest-mcp";
const SERVER_VERSION = "0.1.0";
const ROOT_DIR = process.cwd();
const DEFAULT_PLUGIN_CONFIG = path.join(
  ROOT_DIR,
  "vault",
  ".obsidian",
  "plugins",
  "obsidian-local-rest-api",
  "data.json",
);

function loadLocalRestApiConfig() {
  const configPath = process.env.OBSIDIAN_PLUGIN_CONFIG || DEFAULT_PLUGIN_CONFIG;
  if (!fs.existsSync(configPath)) {
    return null;
  }

  const raw = fs.readFileSync(configPath, "utf8");
  const parsed = JSON.parse(raw);
  return {
    configPath,
    apiKey: parsed.apiKey,
    securePort: parsed.port,
    insecurePort: parsed.insecurePort,
    insecureEnabled: parsed.enableInsecureServer === true,
  };
}

function getServerConfig() {
  const pluginConfig = loadLocalRestApiConfig();
  const useInsecure = process.env.OBSIDIAN_USE_INSECURE === "1";
  const hostname = process.env.OBSIDIAN_HOST || "127.0.0.1";
  const apiKey = process.env.OBSIDIAN_API_KEY || pluginConfig?.apiKey;
  const securePort = Number(process.env.OBSIDIAN_PORT || pluginConfig?.securePort || 27124);
  const insecurePort = Number(
    process.env.OBSIDIAN_INSECURE_PORT || pluginConfig?.insecurePort || 27123,
  );
  const scheme = useInsecure ? "http" : "https";
  const port = useInsecure ? insecurePort : securePort;
  const verifyTls = process.env.OBSIDIAN_VERIFY_TLS === "1";

  if (!apiKey) {
    throw new Error(
      "Missing Obsidian API key. Set OBSIDIAN_API_KEY or keep Local REST API config at vault/.obsidian/plugins/obsidian-local-rest-api/data.json.",
    );
  }

  return {
    apiKey,
    baseUrl: `${scheme}://${hostname}:${port}`,
    verifyTls,
    pluginConfig,
  };
}

const OBSIDIAN = getServerConfig();

function makeRequest(method, requestPath, { body, headers } = {}) {
  const url = new URL(requestPath, `${OBSIDIAN.baseUrl}/`);
  const isHttps = url.protocol === "https:";
  const transport = isHttps ? https : http;
  const payload = body == null ? null : typeof body === "string" ? body : JSON.stringify(body);

  return new Promise((resolve, reject) => {
    const req = transport.request(
      url,
      {
        method,
        rejectUnauthorized: OBSIDIAN.verifyTls,
        headers: {
          Authorization: `Bearer ${OBSIDIAN.apiKey}`,
          Accept: "application/json",
          ...(payload != null
            ? {
                "Content-Length": Buffer.byteLength(payload),
              }
            : {}),
          ...headers,
        },
      },
      (res) => {
        const chunks = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () => {
          const raw = Buffer.concat(chunks).toString("utf8");
          const contentType = res.headers["content-type"] || "";
          let parsed = raw;

          if (contentType.includes("application/json")) {
            try {
              parsed = raw ? JSON.parse(raw) : {};
            } catch {
              parsed = raw;
            }
          }

          if ((res.statusCode || 500) >= 400) {
            const message =
              typeof parsed === "object" && parsed && "message" in parsed
                ? parsed.message
                : `Obsidian request failed with status ${res.statusCode}`;
            reject(new Error(message));
            return;
          }

          resolve({
            status: res.statusCode || 200,
            headers: res.headers,
            data: parsed,
          });
        });
      },
    );

    req.on("error", reject);

    if (payload != null) {
      req.write(payload);
    }

    req.end();
  });
}

function encodeVaultPath(notePath) {
  return notePath
    .split("/")
    .map((part) => encodeURIComponent(part))
    .join("/");
}

function normalizeDirectory(directory = "") {
  return directory.replace(/\\/g, "/").replace(/^\/+/, "");
}

function noteText(pathname, description, inputSchema) {
  return {
    name: pathname,
    description,
    inputSchema,
  };
}

const toolDefinitions = [
  noteText("obsidian_list_files", "List files or folders under a vault directory.", {
    type: "object",
    properties: {
      directory: {
        type: "string",
        description: "Directory relative to the vault root. Empty means root.",
      },
    },
    additionalProperties: false,
  }),
  noteText("obsidian_get_note", "Read a note from the vault.", {
    type: "object",
    properties: {
      path: {
        type: "string",
        description: "Path to the note relative to the vault root.",
      },
      format: {
        type: "string",
        enum: ["markdown", "json", "document_map"],
        description: "Response format.",
      },
    },
    required: ["path"],
    additionalProperties: false,
  }),
  noteText("obsidian_search", "Run a simple text search across markdown notes.", {
    type: "object",
    properties: {
      query: {
        type: "string",
        description: "Simple search query.",
      },
      contextLength: {
        type: "integer",
        minimum: 0,
        description: "Characters of context to include around matches.",
      },
    },
    required: ["query"],
    additionalProperties: false,
  }),
  noteText("obsidian_put_note", "Create or fully replace a note.", {
    type: "object",
    properties: {
      path: {
        type: "string",
        description: "Path to the note relative to the vault root.",
      },
      content: {
        type: "string",
        description: "Complete markdown content.",
      },
    },
    required: ["path", "content"],
    additionalProperties: false,
  }),
  noteText("obsidian_append_note", "Append markdown content to a note.", {
    type: "object",
    properties: {
      path: {
        type: "string",
        description: "Path to the note relative to the vault root.",
      },
      content: {
        type: "string",
        description: "Markdown content to append.",
      },
    },
    required: ["path", "content"],
    additionalProperties: false,
  }),
  noteText("obsidian_patch_note", "Insert or replace content relative to a heading, block, or frontmatter field.", {
    type: "object",
    properties: {
      path: {
        type: "string",
        description: "Path to the note relative to the vault root.",
      },
      operation: {
        type: "string",
        enum: ["append", "prepend", "replace"],
      },
      targetType: {
        type: "string",
        enum: ["heading", "block", "frontmatter"],
      },
      target: {
        type: "string",
        description: "Heading path, block id, or frontmatter field name.",
      },
      content: {
        type: "string",
        description: "Markdown or JSON string content to apply.",
      },
      contentType: {
        type: "string",
        enum: ["text/markdown", "application/json"],
      },
      createTargetIfMissing: {
        type: "boolean",
        description: "Create the target if it does not exist.",
      },
    },
    required: ["path", "operation", "targetType", "target", "content"],
    additionalProperties: false,
  }),
  noteText("obsidian_open_note", "Open a note in the Obsidian UI.", {
    type: "object",
    properties: {
      path: {
        type: "string",
        description: "Path to the note relative to the vault root.",
      },
      newLeaf: {
        type: "boolean",
        description: "Open in a new leaf.",
      },
    },
    required: ["path"],
    additionalProperties: false,
  }),
];

async function callTool(name, args = {}) {
  switch (name) {
    case "obsidian_list_files": {
      const directory = normalizeDirectory(args.directory || "");
      const suffix = directory ? `${encodeVaultPath(directory)}/` : "";
      const response = await makeRequest("GET", `/vault/${suffix}`);
      return {
        directory,
        files: response.data.files || [],
      };
    }
    case "obsidian_get_note": {
      const format = args.format || "markdown";
      const headers =
        format === "json"
          ? { Accept: "application/vnd.olrapi.note+json" }
          : format === "document_map"
            ? { Accept: "application/vnd.olrapi.document-map+json" }
            : { Accept: "text/markdown" };
      const response = await makeRequest("GET", `/vault/${encodeVaultPath(args.path)}`, { headers });
      return {
        path: args.path,
        format,
        note: response.data,
      };
    }
    case "obsidian_search": {
      const query = encodeURIComponent(args.query);
      const contextLength =
        typeof args.contextLength === "number" ? `&contextLength=${args.contextLength}` : "";
      const response = await makeRequest("POST", `/search/simple/?query=${query}${contextLength}`);
      return response.data;
    }
    case "obsidian_put_note": {
      await makeRequest("PUT", `/vault/${encodeVaultPath(args.path)}`, {
        body: args.content,
        headers: {
          "Content-Type": "text/markdown; charset=utf-8",
          Accept: "application/json",
        },
      });
      return {
        ok: true,
        path: args.path,
        action: "put",
      };
    }
    case "obsidian_append_note": {
      await makeRequest("POST", `/vault/${encodeVaultPath(args.path)}`, {
        body: args.content,
        headers: {
          "Content-Type": "text/markdown; charset=utf-8",
          Accept: "application/json",
        },
      });
      return {
        ok: true,
        path: args.path,
        action: "append",
      };
    }
    case "obsidian_patch_note": {
      await makeRequest("PATCH", `/vault/${encodeVaultPath(args.path)}`, {
        body: args.content,
        headers: {
          "Content-Type": `${args.contentType || "text/markdown"}; charset=utf-8`,
          Accept: "application/json",
          Operation: args.operation,
          "Target-Type": args.targetType,
          Target: args.target,
          ...(args.createTargetIfMissing ? { "Create-Target-If-Missing": "true" } : {}),
        },
      });
      return {
        ok: true,
        path: args.path,
        action: "patch",
        operation: args.operation,
        targetType: args.targetType,
        target: args.target,
      };
    }
    case "obsidian_open_note": {
      const encodedPath = encodeVaultPath(args.path);
      const query = args.newLeaf ? "?newLeaf=true" : "";
      await makeRequest("POST", `/open/${encodedPath}${query}`, {
        headers: {
          Accept: "application/json",
        },
      });
      return {
        ok: true,
        path: args.path,
        action: "open",
      };
    }
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

function makeToolResult(result) {
  return {
    content: [
      {
        type: "text",
        text: JSON.stringify(result, null, 2),
      },
    ],
  };
}

function writeMessage(message) {
  const json = JSON.stringify(message);
  const payload = Buffer.from(json, "utf8");
  process.stdout.write(`Content-Length: ${payload.length}\r\n\r\n`);
  process.stdout.write(payload);
}

function writeResponse(id, result) {
  writeMessage({
    jsonrpc: "2.0",
    id,
    result,
  });
}

function writeError(id, error, code = -32000) {
  writeMessage({
    jsonrpc: "2.0",
    id,
    error: {
      code,
      message: error instanceof Error ? error.message : String(error),
    },
  });
}

async function handleRequest(message) {
  const { id, method, params } = message;

  try {
    if (method === "initialize") {
      writeResponse(id, {
        protocolVersion: "2024-11-05",
        capabilities: {
          tools: {},
        },
        serverInfo: {
          name: SERVER_NAME,
          version: SERVER_VERSION,
        },
      });
      return;
    }

    if (method === "notifications/initialized") {
      return;
    }

    if (method === "tools/list") {
      writeResponse(id, {
        tools: toolDefinitions,
      });
      return;
    }

    if (method === "tools/call") {
      const result = await callTool(params.name, params.arguments || {});
      writeResponse(id, makeToolResult(result));
      return;
    }

    if (id != null) {
      writeError(id, `Unsupported method: ${method}`, -32601);
    }
  } catch (error) {
    if (id != null) {
      writeError(id, error);
    }
  }
}

let inputBuffer = Buffer.alloc(0);
let pendingRequests = 0;
let stdinEnded = false;

function maybeExit() {
  if (stdinEnded && pendingRequests === 0) {
    process.exit(0);
  }
}

function processInput() {
  while (true) {
    const headerEnd = inputBuffer.indexOf("\r\n\r\n");
    if (headerEnd === -1) {
      return;
    }

    const headerText = inputBuffer.slice(0, headerEnd).toString("utf8");
    const headers = Object.fromEntries(
      headerText
        .split("\r\n")
        .map((line) => line.split(/:\s*/, 2))
        .filter(([key, value]) => key && value),
    );
    const contentLength = Number(headers["Content-Length"] || headers["content-length"]);

    if (!Number.isFinite(contentLength)) {
      throw new Error("Missing Content-Length header");
    }

    const totalLength = headerEnd + 4 + contentLength;
    if (inputBuffer.length < totalLength) {
      return;
    }

    const body = inputBuffer.slice(headerEnd + 4, totalLength).toString("utf8");
    inputBuffer = inputBuffer.slice(totalLength);
    const message = JSON.parse(body);
    pendingRequests += 1;
    void Promise.resolve(handleRequest(message)).finally(() => {
      pendingRequests -= 1;
      maybeExit();
    });
  }
}

process.stdin.on("data", (chunk) => {
  inputBuffer = Buffer.concat([inputBuffer, chunk]);
  processInput();
});

process.stdin.on("end", () => {
  stdinEnded = true;
  maybeExit();
});

process.stderr.write(
  `[${SERVER_NAME}] Ready for ${OBSIDIAN.baseUrl} using ${
    OBSIDIAN.pluginConfig ? path.relative(ROOT_DIR, OBSIDIAN.pluginConfig.configPath) : "env config"
  }\n`,
);
