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

// ----- Supplement template management -----

const TIME_SLOT = z.enum(["morning", "pre_lunch", "dinner", "pre_sleep"]);

server.registerTool(
  "list_supplements",
  {
    title: "List supplements",
    description: "List supplement templates. Default returns active; pass archived=true for the archived list.",
    inputSchema: { archived: z.boolean().optional() }
  },
  async ({ archived }) => jsonResult(await api("GET", `/api/v1/supplements${archived ? "?archived=true" : ""}`))
);

server.registerTool(
  "create_supplement",
  {
    title: "Create a supplement",
    description: "Add a supplement. time_slots is optional; each slot becomes a row on /supplements at that time.",
    inputSchema: {
      name:              z.string(),
      dose:              z.string().describe("e.g. '1 capsule' or '5 g'"),
      critical:          z.boolean().optional(),
      notes:             z.string().optional(),
      contraindications: z.string().optional(),
      time_slots:        z.array(TIME_SLOT).optional()
    }
  },
  async ({ time_slots, ...supplement }) => jsonResult(await api("POST", "/api/v1/supplements", { supplement, time_slots }))
);

server.registerTool(
  "update_supplement",
  {
    title: "Update a supplement",
    description: "Edit a supplement by id. Omitted fields are unchanged. Pass time_slots to fully replace the slot assignments (omit to leave them alone).",
    inputSchema: {
      id:                z.number().int().positive(),
      name:              z.string().optional(),
      dose:              z.string().optional(),
      critical:          z.boolean().optional(),
      notes:             z.string().optional(),
      contraindications: z.string().optional(),
      time_slots:        z.array(TIME_SLOT).optional()
    }
  },
  async ({ id, time_slots, ...rest }) => {
    const body = { supplement: rest };
    if (time_slots !== undefined) body.time_slots = time_slots;
    return jsonResult(await api("PATCH", `/api/v1/supplements/${id}`, body));
  }
);

server.registerTool(
  "archive_supplement",
  {
    title: "Archive a supplement",
    description: "Soft-delete a supplement: it disappears from /supplements and adherence calc, but past completion records remain.",
    inputSchema: { id: z.number().int().positive() }
  },
  async ({ id }) => jsonResult(await api("DELETE", `/api/v1/supplements/${id}`))
);

server.registerTool(
  "restore_supplement",
  {
    title: "Restore a supplement",
    description: "Un-archive a supplement.",
    inputSchema: { id: z.number().int().positive() }
  },
  async ({ id }) => jsonResult(await api("PATCH", `/api/v1/supplements/${id}/restore`))
);

// ----- Habit (ChecklistTemplate) management -----

server.registerTool(
  "list_habits",
  {
    title: "List habits",
    description: "List habit templates. Default returns active in display order; pass archived=true for the archived list.",
    inputSchema: { archived: z.boolean().optional() }
  },
  async ({ archived }) => jsonResult(await api("GET", `/api/v1/habits${archived ? "?archived=true" : ""}`))
);

server.registerTool(
  "create_habit",
  {
    title: "Create a habit",
    description: "Add a habit. New habits get appended at the bottom of the order.",
    inputSchema: {
      label:       z.string(),
      description: z.string().optional(),
      icon:        z.string().optional().describe("single emoji")
    }
  },
  async (habit) => jsonResult(await api("POST", "/api/v1/habits", { habit }))
);

server.registerTool(
  "update_habit",
  {
    title: "Update a habit",
    description: "Edit a habit by id. Pass an integer position to reorder (lower = earlier on /checklist).",
    inputSchema: {
      id:          z.number().int().positive(),
      label:       z.string().optional(),
      description: z.string().optional(),
      icon:        z.string().optional(),
      position:    z.number().int().nonnegative().optional()
    }
  },
  async ({ id, ...habit }) => jsonResult(await api("PATCH", `/api/v1/habits/${id}`, { habit }))
);

server.registerTool(
  "archive_habit",
  {
    title: "Archive a habit",
    description: "Soft-delete a habit: it disappears from /checklist and adherence calc, but past completion records remain.",
    inputSchema: { id: z.number().int().positive() }
  },
  async ({ id }) => jsonResult(await api("DELETE", `/api/v1/habits/${id}`))
);

server.registerTool(
  "restore_habit",
  {
    title: "Restore a habit",
    description: "Un-archive a habit; it's appended at the bottom of the order.",
    inputSchema: { id: z.number().int().positive() }
  },
  async ({ id }) => jsonResult(await api("PATCH", `/api/v1/habits/${id}/restore`))
);

// ----- Settings: macro targets (plan/meal/goal) -----

const PLAN_SLUG = z.enum(["exercise", "active", "rest"]);
const HHMM      = z.string().regex(/^\d{1,2}:\d{2}$/, "expected HH:MM in 24-hour clock");
const GOAL_METRIC = z.enum([
  "weight_kg", "body_fat_pct", "hdl", "hs_crp", "visceral_fat", "muscle_mass_kg"
]);

async function resolvePlanIdBySlug(slug) {
  const res = await api("GET", "/api/v1/plans");
  const plan = (res.plans || []).find(p => p.slug === slug);
  if (!plan) throw new Error(`No plan with slug "${slug}". Valid: exercise, active, rest`);
  return plan.id;
}

async function resolveGoalIdByMetric(metric) {
  const res = await api("GET", "/api/v1/goals");
  const goal = (res.goals || []).find(g => g.metric === metric);
  if (!goal) throw new Error(`No goal exists for metric "${metric}".`);
  return goal.id;
}

server.registerTool(
  "update_plan",
  {
    title: "Update plan macro targets",
    description: "Update macro targets for one of the three day types. Pass any subset of target_kcal, target_protein_g, target_carbs_g, target_fat_g.",
    inputSchema: {
      slug:             PLAN_SLUG,
      target_kcal:      z.number().int().positive().optional(),
      target_protein_g: z.number().positive().optional(),
      target_carbs_g:   z.number().positive().optional(),
      target_fat_g:     z.number().positive().optional()
    }
  },
  async ({ slug, ...rest }) => {
    if (Object.keys(rest).length === 0) {
      throw new Error("no updatable fields provided");
    }
    const id = await resolvePlanIdBySlug(slug);
    return jsonResult(await api("PATCH", `/api/v1/plans/${id}`, { plan: rest }));
  }
);

server.registerTool(
  "update_meal",
  {
    title: "Update a meal",
    description: "Rename a meal, reschedule it (HH:MM), or change per-meal macro targets. Looks up the meal by name on the given plan (defaults to today's plan if plan_slug omitted).",
    inputSchema: {
      plan_slug:        PLAN_SLUG.optional(),
      name:             z.string().describe("current meal name, e.g. 'Breakfast'"),
      scheduled_time:   HHMM.optional(),
      target_kcal:      z.number().int().positive().optional(),
      target_protein_g: z.number().positive().optional(),
      target_carbs_g:   z.number().positive().optional(),
      target_fat_g:     z.number().positive().optional()
    }
  },
  async ({ plan_slug, name, ...rest }) => {
    if (Object.keys(rest).length === 0) {
      throw new Error("no updatable fields provided");
    }
    const meal = await resolveMealId({ name, plan_slug });
    return jsonResult(await api("PATCH", `/api/v1/meals/${meal.id}`, { meal: rest }));
  }
);

server.registerTool(
  "update_goal",
  {
    title: "Update a goal target",
    description: "Update target_value for a tracked goal, looked up by metric.",
    inputSchema: {
      metric:       GOAL_METRIC,
      target_value: z.number()
    }
  },
  async ({ metric, target_value }) => {
    const id = await resolveGoalIdByMetric(metric);
    return jsonResult(await api("PATCH", `/api/v1/goals/${id}`, { goal: { target_value } }));
  }
);

// ----- Meal-item CRUD (food items inside a planned meal) -----

async function resolveMealItemId({ plan_slug, meal_name, food_name }) {
  const meal = await resolveMealId({ name: meal_name, plan_slug });
  const items = await api("GET", `/api/v1/meals/${meal.id}/items`);
  const found = (items.meal_items || []).find(i => i.food_name.toLowerCase() === food_name.toLowerCase());
  if (!found) {
    const available = (items.meal_items || []).map(i => i.food_name).join(", ");
    throw new Error(`No food matching "${food_name}" in meal "${meal_name}". Current items: ${available}`);
  }
  return { mealId: meal.id, itemId: found.id };
}

server.registerTool(
  "list_meal_items",
  {
    title: "List meal items",
    description: "List the food items inside one meal on a plan, with computed kcal and macros per item.",
    inputSchema: {
      plan_slug: PLAN_SLUG.optional(),
      meal_name: z.string().describe("meal name, e.g. 'Breakfast'")
    }
  },
  async ({ plan_slug, meal_name }) => {
    const meal = await resolveMealId({ name: meal_name, plan_slug });
    return jsonResult(await api("GET", `/api/v1/meals/${meal.id}/items`));
  }
);

server.registerTool(
  "add_meal_item",
  {
    title: "Add a food to a meal",
    description: "Attach a food (by name) to a meal at a given gram quantity.",
    inputSchema: {
      plan_slug:      PLAN_SLUG.optional(),
      meal_name:      z.string(),
      food_name:      z.string(),
      quantity_grams: z.number().positive()
    }
  },
  async ({ plan_slug, meal_name, food_name, quantity_grams }) => {
    const meal = await resolveMealId({ name: meal_name, plan_slug });
    const food = await resolveFoodId(food_name);
    return jsonResult(await api("POST", `/api/v1/meals/${meal.id}/items`,
      { meal_item: { food_id: food.id, quantity_grams } }));
  }
);

server.registerTool(
  "update_meal_item",
  {
    title: "Update a meal item's quantity",
    description: "Change the gram quantity of an existing food item in a meal. Highest-leverage portion-correction tool.",
    inputSchema: {
      plan_slug:      PLAN_SLUG.optional(),
      meal_name:      z.string(),
      food_name:      z.string().describe("name of the food currently in the meal"),
      quantity_grams: z.number().positive()
    }
  },
  async ({ plan_slug, meal_name, food_name, quantity_grams }) => {
    const { itemId } = await resolveMealItemId({ plan_slug, meal_name, food_name });
    return jsonResult(await api("PATCH", `/api/v1/meal_items/${itemId}`,
      { meal_item: { quantity_grams } }));
  }
);

server.registerTool(
  "remove_meal_item",
  {
    title: "Remove a food from a meal",
    description: "Drop a food from a meal entirely (e.g., remove a stacked fat source).",
    inputSchema: {
      plan_slug: PLAN_SLUG.optional(),
      meal_name: z.string(),
      food_name: z.string()
    }
  },
  async ({ plan_slug, meal_name, food_name }) => {
    const { itemId } = await resolveMealItemId({ plan_slug, meal_name, food_name });
    return jsonResult(await api("DELETE", `/api/v1/meal_items/${itemId}`));
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
