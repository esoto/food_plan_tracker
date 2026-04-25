#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const BASE_URL = process.env.FOOD_API_BASE_URL || "http://localhost:3000";
const TOKEN    = process.env.FOOD_API_TOKEN;

if (!TOKEN) {
  console.error("FOOD_API_TOKEN env var is required");
  process.exit(1);
}

async function api(method, path, body) {
  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers: {
      "Authorization": `Bearer ${TOKEN}`,
      "Content-Type": "application/json"
    },
    body: body ? JSON.stringify(body) : undefined
  });
  const text = await res.text();
  let parsed;
  try { parsed = text ? JSON.parse(text) : {}; } catch { parsed = { raw: text }; }
  if (!res.ok) {
    throw new Error(`API ${method} ${path} → ${res.status}: ${parsed.error || text}`);
  }
  return parsed;
}

function jsonResult(payload) {
  return { content: [{ type: "text", text: JSON.stringify(payload, null, 2) }] };
}

const server = new McpServer({ name: "food-tracker", version: "0.1.0" });

server.registerTool(
  "get_today_status",
  {
    title: "Get today's status",
    description: "Today's plan, macro targets, consumed macros, weight, completed meals, now_meal, and logged foods.",
    inputSchema: {}
  },
  async () => jsonResult(await api("GET", "/api/v1/today"))
);

const transport = new StdioServerTransport();
await server.connect(transport);
