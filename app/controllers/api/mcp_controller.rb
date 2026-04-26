module Api
  # Streamable HTTP transport for the Model Context Protocol. Claude (web,
  # desktop, mobile) speaks JSON-RPC 2.0 over POST. We implement just the
  # three methods a tools-only server needs (initialize, tools/list,
  # tools/call) and return 405 on other HTTP verbs since we run stateless
  # — every request stands on its own access token, no session continuity.
  #
  # Tool handlers reuse the same model code that backs /api/v1/* by way of
  # the DaySerializer concern, so the wire shape Claude sees is byte-for-
  # byte identical to the JSON the existing API returns. That keeps the
  # cognitive load on Claude minimal.
  class McpController < ActionController::API
    include Api::Concerns::DaySerializer

    PROTOCOL_VERSION = "2025-06-18".freeze
    SERVER_INFO      = { name: "food-tracker", version: "0.2.0" }.freeze

    rate_limit to: 120, within: 1.minute, by: -> { request.remote_ip },
               with: -> { render json: rpc_error(nil, -32000, "rate_limited"), status: :too_many_requests }

    before_action :reject_unsupported_methods
    before_action :doorkeeper_authorize!, only: :handle

    rescue_from StandardError do |error|
      Rails.logger.error("[mcp] #{error.class}: #{error.message}")
      render json: rpc_error(@rpc_id, -32603, error.message), status: :ok
    end

    def handle
      msg = parse_message
      @rpc_id = msg["id"]
      method  = msg["method"]
      params  = msg["params"] || {}

      # Notifications (no id) get an empty 202 — they don't expect a body.
      if @rpc_id.nil?
        return head(:accepted)
      end

      result = case method
      when "initialize"   then initialize_result(params)
      when "tools/list"   then { tools: tool_descriptors }
      when "tools/call"   then call_tool(params)
      else
                 return render(json: rpc_error(@rpc_id, -32601, "method not found: #{method}"))
      end

      render json: { jsonrpc: "2.0", id: @rpc_id, result: result }
    end

    private

    def reject_unsupported_methods
      head(:method_not_allowed) unless request.post?
    end

    def parse_message
      @parsed_message ||= JSON.parse(request.raw_post.presence || "{}")
    rescue JSON::ParserError
      @parsed_message = {}
    end

    def initialize_result(_params)
      {
        protocolVersion: PROTOCOL_VERSION,
        capabilities:    { tools: { listChanged: false } },
        serverInfo:      SERVER_INFO
      }
    end

    def call_tool(params)
      name      = params["name"]
      arguments = params["arguments"] || {}
      tool      = TOOLS.find { |t| t[:name] == name }

      return tool_error("unknown tool: #{name}") unless tool

      payload = instance_exec(arguments, &tool[:handler])
      { content: [ { type: "text", text: JSON.pretty_generate(payload) } ] }
    rescue StandardError => e
      tool_error(e.message)
    end

    def tool_error(message)
      { content: [ { type: "text", text: "Error: #{message}" } ], isError: true }
    end

    def tool_descriptors
      TOOLS.map { |t| t.slice(:name, :description, :inputSchema) }
    end

    def rpc_error(id, code, message)
      { jsonrpc: "2.0", id: id, error: { code: code, message: message } }
    end

    # ----- Tool handlers (called via instance_exec so they can use the
    # ----- DaySerializer methods that are private to this class).

    def handle_get_today_status(_args)
      serialize_day(DailyLog.today)
    end

    def handle_get_day_status(args)
      serialize_day(DailyLog.for(Date.parse(args.fetch("date"))))
    end

    def handle_log_weight(args)
      goal = Goal.find_by!(metric: Goal.metrics[:weight_kg])
      date = args["date"].present? ? Date.parse(args["date"].to_s) : Date.current
      entry = goal.biomarker_entries.create!(value: args.fetch("value"), recorded_on: date)
      log = DailyLog.for(date)
      log.update!(weight_kg: entry.value) if log.date == entry.recorded_on
      { ok: true,
        entry: { id: entry.id, value: entry.value.to_f, recorded_on: entry.recorded_on.iso8601 },
        day:   serialize_day(log.reload) }
    end

    def handle_complete_meal(args)
      meal = resolve_meal(args)
      log  = DailyLog.for(args["date"].present? ? Date.parse(args["date"]) : Date.current)
      log.meal_completions.find_or_create_by!(meal: meal) { |mc| mc.completed_at = Time.current }
      { ok: true, day: serialize_day(log.reload) }
    end

    def handle_uncomplete_meal(args)
      meal = resolve_meal(args)
      log  = DailyLog.for(args["date"].present? ? Date.parse(args["date"]) : Date.current)
      completion = log.meal_completions.find_by!(meal: meal)
      completion.destroy!
      { ok: true, day: serialize_day(log.reload) }
    end

    def handle_log_food(args)
      food = resolve_food(args.fetch("name"))
      log  = DailyLog.for(args["date"].present? ? Date.parse(args["date"]) : Date.current)
      qty  = args["quantity_grams"].presence&.to_d || food.serving_grams
      log.logged_foods.create!(food: food, quantity_grams: qty, logged_at: Time.current)
      { ok: true, day: serialize_day(log.reload) }
    end

    def handle_delete_logged_food(args)
      entry = LoggedFood.find(args.fetch("id"))
      log   = entry.daily_log
      entry.destroy!
      { ok: true, day: serialize_day(log.reload) }
    end

    def handle_set_plan_for_day(args)
      log  = DailyLog.for(args["date"].present? ? Date.parse(args["date"]) : Date.current)
      plan = Plan.find_by!(slug: args.fetch("slug"))
      log.update!(plan: plan)
      serialize_day(log.reload)
    end

    def handle_list_goals(_args)
      { goals: Goal.all.map { |g| serialize_goal(g) } }
    end

    def handle_search_foods(args)
      q = args.fetch("q").to_s.downcase
      foods = Food.alphabetical.where("LOWER(name) LIKE ?", "%#{q}%").limit(20)
      { foods: foods.map { |f| serialize_food(f) } }
    end

    def handle_create_food(args)
      food = Food.create!(args.slice("name", "category", "serving_grams", "kcal",
                                     "protein_g", "carbs_g", "fat_g", "notes"))
      { food: serialize_food(food) }
    end

    def handle_active_meals(args)
      plan = if args["plan_slug"].present?
               Plan.find_by!(slug: args["plan_slug"])
      else
               DailyLog.for(args["date"].present? ? Date.parse(args["date"]) : Date.current).plan
      end
      meals = plan.meals.includes(meal_items: :food).ordered
      { plan: serialize_plan(plan), meals: meals.map { |m| serialize_meal(m) } }
    end

    def resolve_food(query)
      food = Food.where("LOWER(name) LIKE ?", "%#{query.downcase}%").first
      raise "no food matches \"#{query}\" — call search_foods to find the canonical name" unless food
      food
    end

    def resolve_meal(args)
      slug = args["plan_slug"]
      plan = if slug.present?
               Plan.find_by!(slug: slug)
      else
               DailyLog.for(args["date"].present? ? Date.parse(args["date"]) : Date.current).plan
      end
      meal = plan.meals.find { |m| m.name.casecmp?(args.fetch("name")) }
      raise "no meal \"#{args['name']}\" on plan \"#{plan.slug}\"" unless meal
      meal
    end

    # ----- Tool registry. Schemas mirror the Zod definitions in the
    # ----- existing Node MCP server (mcp/index.js); see that file for
    # ----- prose descriptions of each parameter's intent.

    ISO_DATE_PATTERN = '^\\d{4}-\\d{2}-\\d{2}$'.freeze
    PLAN_SLUGS       = %w[exercise active rest].freeze
    DATE_PROP        = { type: "string", pattern: ISO_DATE_PATTERN, description: "YYYY-MM-DD; defaults to today when omitted" }.freeze

    TOOLS = [
      {
        name:        "get_today_status",
        description: "Today's plan, macro targets, consumed macros, weight, completed meals, now_meal, and logged foods.",
        inputSchema: { type: "object", properties: {} },
        handler:     ->(args) { handle_get_today_status(args) }
      },
      {
        name:        "get_day_status",
        description: "Same shape as get_today_status, for a specific date (YYYY-MM-DD).",
        inputSchema: { type: "object", properties: { "date" => DATE_PROP }, required: %w[date] },
        handler:     ->(args) { handle_get_day_status(args) }
      },
      {
        name:        "log_weight",
        description: "Record a body-weight measurement in kg. Defaults to today; pass `date` to backfill.",
        inputSchema: {
          type: "object",
          properties: {
            "value" => { type: "number", exclusiveMinimum: 0, description: "weight in kilograms" },
            "date"  => DATE_PROP
          },
          required: %w[value]
        },
        handler: ->(args) { handle_log_weight(args) }
      },
      {
        name:        "complete_meal",
        description: "Look up a meal by name (e.g. 'Breakfast') on the active plan and mark it complete.",
        inputSchema: {
          type: "object",
          properties: {
            "name"      => { type: "string", description: "meal name, e.g. 'Breakfast', 'Lunch', 'Dinner'" },
            "plan_slug" => { type: "string", enum: PLAN_SLUGS, description: "if omitted, uses the day's currently selected plan" },
            "date"      => DATE_PROP
          },
          required: %w[name]
        },
        handler: ->(args) { handle_complete_meal(args) }
      },
      {
        name:        "uncomplete_meal",
        description: "Remove a meal completion. Same lookup as complete_meal.",
        inputSchema: {
          type: "object",
          properties: {
            "name"      => { type: "string" },
            "plan_slug" => { type: "string", enum: PLAN_SLUGS },
            "date"      => DATE_PROP
          },
          required: %w[name]
        },
        handler: ->(args) { handle_uncomplete_meal(args) }
      },
      {
        name:        "log_food",
        description: "Resolve a food by name (case-insensitive partial match) and log a serving. Defaults to the food's serving_grams.",
        inputSchema: {
          type: "object",
          properties: {
            "name"           => { type: "string", description: "food name, e.g. 'Chicken breast'" },
            "quantity_grams" => { type: "number", exclusiveMinimum: 0 },
            "date"           => DATE_PROP
          },
          required: %w[name]
        },
        handler: ->(args) { handle_log_food(args) }
      },
      {
        name:        "delete_logged_food",
        description: "Remove a previously logged food by its id (find ids via get_today_status or get_day_status).",
        inputSchema: {
          type: "object",
          properties: { "id" => { type: "integer", exclusiveMinimum: 0 } },
          required: %w[id]
        },
        handler: ->(args) { handle_delete_logged_food(args) }
      },
      {
        name:        "set_plan_for_day",
        description: "Switch the day's plan (exercise/active/rest). Defaults to today.",
        inputSchema: {
          type: "object",
          properties: {
            "slug" => { type: "string", enum: PLAN_SLUGS },
            "date" => DATE_PROP
          },
          required: %w[slug]
        },
        handler: ->(args) { handle_set_plan_for_day(args) }
      },
      {
        name:        "list_goals",
        description: "All tracked goals (weight, body fat, HDL, etc.) with current value, target, and progress percent.",
        inputSchema: { type: "object", properties: {} },
        handler:     ->(args) { handle_list_goals(args) }
      },
      {
        name:        "search_foods",
        description: "Find the canonical name of a food before logging it. Case-insensitive partial match, top 20.",
        inputSchema: {
          type: "object",
          properties: { "q" => { type: "string" } },
          required: %w[q]
        },
        handler: ->(args) { handle_search_foods(args) }
      },
      {
        name:        "create_food",
        description: "Add a new food to the library. All macro values are per a single serving (serving_grams). Notes optional (brand, prep, source).",
        inputSchema: {
          type: "object",
          properties: {
            "name"          => { type: "string" },
            "category"      => { type: "string", enum: %w[protein carb fat vegetable] },
            "serving_grams" => { type: "number", exclusiveMinimum: 0 },
            "kcal"          => { type: "integer", minimum: 0 },
            "protein_g"     => { type: "number", minimum: 0 },
            "carbs_g"       => { type: "number", minimum: 0 },
            "fat_g"         => { type: "number", minimum: 0 },
            "notes"         => { type: "string" }
          },
          required: %w[name category serving_grams kcal protein_g carbs_g fat_g]
        },
        handler: ->(args) { handle_create_food(args) }
      },
      {
        name:        "list_meals",
        description: "List the 5 meals on a plan (defaults to the active plan for today) with per-item macros and per-meal totals — useful for previewing what to eat.",
        inputSchema: {
          type: "object",
          properties: {
            "plan_slug" => { type: "string", enum: PLAN_SLUGS },
            "date"      => DATE_PROP
          }
        },
        handler: ->(args) { handle_active_meals(args) }
      }
    ].freeze
  end
end
