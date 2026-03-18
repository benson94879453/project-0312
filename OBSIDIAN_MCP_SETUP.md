# Obsidian MCP Setup

This repository now includes a local MCP bridge for the Obsidian vault at `vault/`.

## What it does

The server in `tools/obsidian-mcp-server.mjs` connects an MCP client to the Obsidian Local REST API plugin already installed in this vault.

Supported tools:

- `obsidian_list_files`
- `obsidian_get_note`
- `obsidian_search`
- `obsidian_put_note`
- `obsidian_append_note`
- `obsidian_patch_note`
- `obsidian_open_note`

## Requirements

1. Obsidian must be open with this vault.
2. The `Local REST API` community plugin must stay enabled.
3. The plugin server must be running on its configured port.

## Start the MCP server

From this project root:

```powershell
npm run obsidian:mcp
```

The server reads connection settings in this order:

1. `OBSIDIAN_API_KEY`, `OBSIDIAN_HOST`, `OBSIDIAN_PORT`, `OBSIDIAN_USE_INSECURE`, `OBSIDIAN_VERIFY_TLS`
2. `vault/.obsidian/plugins/obsidian-local-rest-api/data.json`

Because the Obsidian plugin usually uses a self-signed certificate, this bridge defaults to skipping TLS verification for the local HTTPS connection. Set `OBSIDIAN_VERIFY_TLS=1` if you have installed the certificate as trusted.

## Example MCP client config

For clients that accept a stdio MCP server command, use:

```json
{
  "mcpServers": {
	"obsidian": {
	  "command": "npm",
	  "args": ["run", "obsidian:mcp"],
	  "cwd": "C:\\Users\\user\\Documents\\GitHub\\project-0312"
	}
  }
}
```

If your client prefers calling Node directly:

```json
{
  "mcpServers": {
	"obsidian": {
	  "command": "node",
	  "args": ["C:\\Users\\user\\Documents\\GitHub\\project-0312\\tools\\obsidian-mcp-server.mjs"]
	}
  }
}
```

## Useful environment overrides

```powershell
$env:OBSIDIAN_API_KEY="replace-me"
$env:OBSIDIAN_HOST="127.0.0.1"
$env:OBSIDIAN_PORT="27124"
$env:OBSIDIAN_USE_INSECURE="0"
$env:OBSIDIAN_VERIFY_TLS="0"
npm run obsidian:mcp
```

## Notes

- Do not commit a copied API key into other config files.
- If the plugin switches to insecure HTTP mode, set `OBSIDIAN_USE_INSECURE=1`.
- `obsidian_patch_note` maps to the plugin's `PATCH /vault/{filename}` endpoint and supports heading, block, and frontmatter targets.
