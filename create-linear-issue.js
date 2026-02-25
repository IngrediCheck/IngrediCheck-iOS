// Requires: npm install @modelcontextprotocol/sdk eventsource-parser node-fetch
// Assumes Linear MCP OAuth is already completed for the environment running this script.

import { SSEClientTransport } from "@modelcontextprotocol/sdk/client/sse.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import fetch from "node-fetch";
import { createParser } from "eventsource-parser";

async function main() {
  const transport = new SSEClientTransport({
    url: "https://mcp.linear.app/mcp",
    fetch,
    createParser,
  });

  const client = new Client(
    {
      name: "ingredicheck-linear-issue-script",
      version: "1.0.0",
    },
    {
      capabilities: {},
    }
  );

  await client.connect(transport);

  const title = "iOS Client: Empty Food Notes — API Changes";

  const description = `
## Context

When a user has no food notes (no dietary preferences configured), the backend now skips LLM analysis entirely. This is faster but means \`overall_match\` can be null instead of always being an enum value.

## Affected endpoints

| Endpoint                          | API             |
|-----------------------------------|-----------------|
| POST /v2/scan/barcode             | AI API          |
| POST /v2/scan/{scan_id}/reanalyze | AI API          |
| GET /v2/scan/history              | Supabase Edge   |
| GET /v2/scan/{scan_id}            | Supabase Edge   |

New query parameter: \`nullable_analysis\`

- Add \`?nullable_analysis=true\` to the above endpoints to opt in.
- With it, \`overall_match\` in \`analysis_result\` may be null, meaning "no analysis was performed" (user has no food notes).

## analysis_result for empty food notes

\`\`\`json
{
  "id": "uuid",
  "is_stale": false,
  "overall_analysis": null,
  "overall_match": null,
  "ingredient_analysis": []
}
\`\`\`

## iOS client implementation

1. Add \`nullable_analysis=true\` to all scan-related API calls (barcode, reanalyze, history, detail).
2. Handle \`overall_match == null\` in the scan detail UI:
   - Show a neutral state (e.g. "No dietary preferences set") instead of the match/uncertain/unmatched badge.
   - Consider prompting the user to add food notes.
3. Staleness still works: If a user scans with empty notes, then adds notes, \`is_stale\` will be true — prompt reanalysis as before.
`;

  const teamKey = process.env.LINEAR_TEAM_KEY || "IOS"; // update to your actual Linear team key
  const assigneeEmail = "gunjan.haldar@ingredicheck.com";
  const state = "Processing";

  const result = await client.callTool({
    name: "linear_create_issue",
    arguments: {
      title,
      description,
      team: teamKey,
      assignee: assigneeEmail,
      state,
    },
  });

  console.log("Linear issue created:", JSON.stringify(result, null, 2));

  await client.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

