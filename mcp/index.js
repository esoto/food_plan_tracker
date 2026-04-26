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

const ISO_DATE = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "expected YYYY-MM-DD");

async function resolveFoodId(query) {
  const res = await api("GET", `/api/v1/foods?q=${encodeURIComponent(query)}`);
  const foods = res.foods || [];
  if (foods.length === 0) throw new Error(`No food matches "${query}". Try search_foods to find the right name.`);
  return foods[0];
}

async function resolveMealId({ name, plan_slug, date }) {
  let plan = plan_slug;
  if (!plan) {
    const today = await api("GET", date ? `/api/v1/days/${date}` : "/api/v1/today");
    plan = today.plan.slug;
  }
  const res = await api("GET", `/api/v1/meals?plan=${encodeURIComponent(plan)}`);
  const meal = (res.meals || []).find(m => m.name.toLowerCase() === name.toLowerCase());
  if (!meal) throw new Error(`No meal "${name}" on plan "${plan}". Available: ${(res.meals || []).map(m => m.name).join(", ")}`);
  return meal;
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

server.registerTool(
  "get_weekly_summary",
  {
    title: "Get last-7-days summary",
    description: "Rolling 7-day recap: avg habits adherence %, weight delta in kg (negative = weight loss), meal completion %, supplement adherence %. Any metric may be null when there's no data to compute it.",
    inputSchema: {}
  },
  async () => jsonResult(await api("GET", "/api/v1/weekly_summary"))
);

server.registerTool(
  "get_day_status",
  {
    title: "Get a past day's status",
    description: "Same shape as get_today_status, for a specific date (YYYY-MM-DD).",
    inputSchema: { date: ISO_DATE }
  },
  async ({ date }) => jsonResult(await api("GET", `/api/v1/days/${date}`))
);

server.registerTool(
  "log_weight",
  {
    title: "Log weight",
    description: "Record a body-weight measurement in kg. Defaults to today; pass `date` to backfill.",
    inputSchema: {
      value: z.number().positive().describe("weight in kilograms"),
      date: ISO_DATE.optional()
    }
  },
  async ({ value, date }) => jsonResult(await api("POST", "/api/v1/weight", { value, date }))
);

server.registerTool(
  "complete_meal",
  {
    title: "Mark a meal complete",
    description: "Look up a meal by name (e.g. 'Breakfast') on the active plan and mark it complete.",
    inputSchema: {
      name: z.string().describe("meal name, e.g. 'Breakfast', 'Lunch', 'Dinner'"),
      plan_slug: z.enum(["exercise", "active", "rest"]).optional().describe("if omitted, uses the day's currently selected plan"),
      date: ISO_DATE.optional()
    }
  },
  async ({ name, plan_slug, date }) => {
    const meal = await resolveMealId({ name, plan_slug, date });
    return jsonResult(await api("POST", `/api/v1/meals/${meal.id}/complete`, { date }));
  }
);

server.registerTool(
  "uncomplete_meal",
  {
    title: "Unmark a meal as complete",
    description: "Remove a meal completion. Same lookup as complete_meal.",
    inputSchema: {
      name: z.string(),
      plan_slug: z.enum(["exercise", "active", "rest"]).optional(),
      date: ISO_DATE.optional()
    }
  },
  async ({ name, plan_slug, date }) => {
    const meal = await resolveMealId({ name, plan_slug, date });
    return jsonResult(await api("DELETE", `/api/v1/meals/${meal.id}/complete?date=${date || ""}`));
  }
);

server.registerTool(
  "copy_yesterday_meals",
  {
    title: "Copy yesterday's meal completions onto today",
    description: "Marks today's meals as complete using yesterday's completions, when both days share a plan. Idempotent — meals already completed today are preserved. Pass `date` to copy onto a different target day (the day before that date is the source).",
    inputSchema: {
      date: ISO_DATE.optional().describe("target day; defaults to today")
    }
  },
  async ({ date }) => jsonResult(await api("POST", "/api/v1/meal_completions/copy_yesterday", { date }))
);

server.registerTool(
  "log_food",
  {
    title: "Log a food",
    description: "Resolve a food by name (case-insensitive partial match) and log a serving. Defaults to the food's serving_grams.",
    inputSchema: {
      name: z.string().describe("food name, e.g. 'Chicken breast'"),
      quantity_grams: z.number().positive().optional(),
      date: ISO_DATE.optional()
    }
  },
  async ({ name, quantity_grams, date }) => {
    const food = await resolveFoodId(name);
    return jsonResult(await api("POST", `/api/v1/foods/${food.id}/log`, { quantity_grams, date }));
  }
);

server.registerTool(
  "delete_logged_food",
  {
    title: "Delete a logged food",
    description: "Remove a previously logged food by its id (find ids via get_today_status or get_day_status).",
    inputSchema: { id: z.number().int().positive() }
  },
  async ({ id }) => jsonResult(await api("DELETE", `/api/v1/logged_foods/${id}`))
);

server.registerTool(
  "set_plan_for_day",
  {
    title: "Set the plan for a day",
    description: "Switch the day's plan (exercise/active/rest). Defaults to today.",
    inputSchema: {
      slug: z.enum(["exercise", "active", "rest"]),
      date: ISO_DATE.optional()
    }
  },
  async ({ slug, date }) => {
    const target = date || new Date().toISOString().slice(0, 10);
    return jsonResult(await api("PATCH", `/api/v1/days/${target}/plan`, { slug }));
  }
);

server.registerTool(
  "list_goals",
  {
    title: "List goals",
    description: "All tracked goals (weight, body fat, HDL, etc.) with current value, target, and progress percent.",
    inputSchema: {}
  },
  async () => jsonResult(await api("GET", "/api/v1/goals"))
);

server.registerTool(
  "search_foods",
  {
    title: "Search foods",
    description: "Find the canonical name of a food before logging it. Case-insensitive partial match, top 20.",
    inputSchema: { q: z.string() }
  },
  async ({ q }) => jsonResult(await api("GET", `/api/v1/foods?q=${encodeURIComponent(q)}`))
);

server.registerTool(
  "create_food",
  {
    title: "Create a food",
    description: "Add a new food to the library. All macro values are per a single serving (serving_grams). Notes optional (brand, prep, source).",
    inputSchema: {
      name:          z.string(),
      category:      z.enum(["protein", "carb", "fat", "vegetable"]),
      serving_grams: z.number().positive(),
      kcal:          z.number().int().nonnegative(),
      protein_g:     z.number().nonnegative(),
      carbs_g:       z.number().nonnegative(),
      fat_g:         z.number().nonnegative(),
      notes:         z.string().optional()
    }
  },
  async (food) => jsonResult(await api("POST", "/api/v1/foods", { food }))
);

const transport = new StdioServerTransport();
await server.connect(transport);
