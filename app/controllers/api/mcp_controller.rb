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

    # Tool-input failures (bad date, missing food, missing required arg)
    # bubble up to the user as `isError: true` with their message intact.
    # Anything else is a bug — log with backtrace and return a generic
    # "internal error" so we don't leak DB column names, file paths, or
    # SQL fragments back to the client.
    class ToolArgumentError < StandardError; end
    USER_ERRORS = [ ToolArgumentError, ActiveRecord::RecordInvalid,
                   ActiveRecord::RecordNotFound, ArgumentError, KeyError, Date::Error,
                   Meal::InvalidScheduledTime ].freeze

    PROTOCOL_VERSION = "2025-06-18".freeze
    SERVER_INFO      = { name: "food-tracker", version: "0.2.0" }.freeze

    rate_limit to: 120, within: 1.minute, by: -> { request.remote_ip },
               with: -> { render json: rpc_error(nil, -32000, "rate_limited"), status: :too_many_requests }

    before_action :reject_unsupported_methods
    before_action :doorkeeper_authorize!, only: :handle
    before_action :set_current_session, only: :handle

    rescue_from StandardError do |error|
      Rails.logger.error("[mcp] #{error.class}: #{error.message}\n#{error.backtrace&.first(10)&.join("\n")}")
      Rails.error.report(error, context: { rpc_id: @rpc_id, method: @parsed_message&.dig("method") })
      render json: rpc_error(@rpc_id, -32603, "internal_error"), status: :ok
    end

    # Anonymous garbage hitting /mcp used to slip through to the 200
    # internal_error path because Doorkeeper falls back to params lookup
    # when no Authorization header is present, and the params parser
    # raises ParseError before doorkeeper_authorize! can return 401.
    # Catch parse errors explicitly so they (a) return the spec-correct
    # JSON-RPC parse_error code, (b) return HTTP 400 instead of 200, and
    # (c) don't get logged as application errors. Declared after the
    # StandardError handler so it takes precedence (Rescuable searches
    # handlers in reverse declaration order).
    #
    # Scoped to ParseError specifically (not JSON::ParserError) so that a
    # future tool handler that calls JSON.parse on user input won't have
    # its failure misclassified as a transport-level parse error with
    # `id: nil`. parse_message rewraps its own JSON::ParserError into
    # ParseError so both the middleware-driven path and the controller's
    # explicit body parse end up here.
    rescue_from ActionDispatch::Http::Parameters::ParseError do
      render json: rpc_error(nil, -32700, "parse error"), status: :bad_request
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

    def set_current_session
      return unless doorkeeper_token

      user = User.find_by(id: doorkeeper_token.resource_owner_id)
      Current.user = user if user
    end

    def parse_message
      # An empty body is legal (the JSON-RPC notification short-circuit
      # below still fires). A malformed body is rewrapped as ParseError
      # so the single class-level rescue handles both this path and the
      # one Doorkeeper triggers via params-lookup fallback. Note that
      # ActionDispatch::Http::Parameters::ParseError takes no args — its
      # constructor reads $!.message from the active rescue context.
      @parsed_message ||= JSON.parse(request.raw_post.presence || "{}")
    rescue JSON::ParserError
      raise ActionDispatch::Http::Parameters::ParseError
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

      payload = send(tool[:handler], arguments)
      { content: [ { type: "text", text: JSON.pretty_generate(payload) } ] }
    rescue *USER_ERRORS => e
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

    # ----- Tool handler shared helpers.

    # Parse the optional "date" arg as YYYY-MM-DD, defaulting to today.
    # Tolerates `nil` and the literal string "null" (which Date.parse
    # would otherwise raise on).
    def date_arg(args, key = "date", default: -> { Date.current })
      raw = args[key]
      raw.present? ? Date.parse(raw.to_s) : default.call
    end

    def log_for(args)
      DailyLog.for(Current.user, date_arg(args))
    end

    def plan_for(args)
      args["plan_slug"].present? ? Plan.find_by_slug!(args["plan_slug"], user: Current.user) : log_for(args).plan
    end

    # ----- Tool handlers.

    def handle_get_today_status(_args)
      serialize_day(DailyLog.today(Current.user))
    end

    def handle_get_day_status(args)
      serialize_day(DailyLog.for(Current.user, date_arg(args, default: -> { raise ToolArgumentError, "date is required" })))
    end

    def handle_log_weight(args)
      goal  = Goal.find_by_metric!(Goal.metrics[:weight_kg], user: Current.user)
      date  = date_arg(args)
      entry = goal.biomarker_entries.create!(value: args.fetch("value"), recorded_on: date)
      log   = DailyLog.for(Current.user, date)
      log.update!(weight_kg: entry.value) if log.date == entry.recorded_on
      { ok: true,
        entry: { id: entry.id, value: entry.value.to_f, recorded_on: entry.recorded_on.iso8601 },
        day:   serialize_day(log.reload) }
    end

    def handle_complete_meal(args)
      meal = resolve_meal(args)
      log  = log_for(args)
      log.meal_completions.find_or_create_by!(meal: meal) { |mc| mc.completed_at = Time.current }
      { ok: true, day: serialize_day(log.reload) }
    end

    def handle_uncomplete_meal(args)
      meal = resolve_meal(args)
      log  = log_for(args)
      log.meal_completions.find_by!(meal: meal).destroy!
      { ok: true, day: serialize_day(log.reload) }
    end

    def handle_log_food(args)
      food = resolve_food(args.fetch("name"))
      log  = log_for(args)
      qty  = args["quantity_grams"].presence&.to_d || food.serving_grams
      log.logged_foods.create!(food: food, quantity_grams: qty, logged_at: Time.current)
      { ok: true, day: serialize_day(log.reload) }
    end

    def handle_delete_logged_food(args)
      entry = Current.user.logged_foods.find(args.fetch("id"))
      log   = entry.daily_log
      entry.destroy!
      { ok: true, day: serialize_day(log.reload) }
    end

    def handle_set_plan_for_day(args)
      log  = log_for(args)
      plan = Plan.find_by_slug!(args.fetch("slug"), user: Current.user)
      log.update!(plan: plan)
      serialize_day(log.reload)
    end

    def handle_list_goals(_args)
      { goals: Current.user.goals.map { |g| serialize_goal(g) } }
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
      plan  = plan_for(args)
      meals = plan.meals.includes(meal_items: :food).ordered
      { plan: serialize_plan(plan), meals: meals.map { |m| serialize_meal(m) } }
    end

    def handle_get_weekly_summary(_args)
      summary = WeeklySummary.rolling_7_days(user: Current.user)
      {
        window_days: 7,
        start_date:  summary.start_date.iso8601,
        end_date:    summary.end_date.iso8601,
        adherence_pct:             summary.adherence_pct,
        weight_delta_kg:           summary.weight_delta_kg,
        meal_completion_pct:       summary.meal_completion_pct,
        supplement_completion_pct: summary.supplement_completion_pct
      }
    end

    def handle_list_supplements(args)
      scope = args["archived"].to_s == "true" ? Current.user.supplements.discarded : Current.user.supplements.kept
      scope = scope.includes(:supplement_schedules).order(critical: :desc, name: :asc)
      { supplements: scope.map { |s| serialize_supplement(s) } }
    end

    def handle_create_supplement(args)
      attrs = args.slice("name", "dose", "critical", "notes", "contraindications")
      supplement = Current.user.supplements.create!(attrs)
      supplement.sync_time_slots!(args["time_slots"]) if args.key?("time_slots")
      { supplement: serialize_supplement(supplement.reload) }
    end

    def handle_update_supplement(args)
      supplement = Current.user.supplements.find(args.fetch("id"))
      attrs = args.slice("name", "dose", "critical", "notes", "contraindications").compact
      raise ToolArgumentError, "no updatable fields provided" if attrs.empty? && !args.key?("time_slots")

      supplement.update!(attrs) if attrs.any?
      supplement.sync_time_slots!(args["time_slots"]) if args.key?("time_slots")
      { supplement: serialize_supplement(supplement.reload) }
    end

    def handle_archive_supplement(args)
      supplement = Current.user.supplements.find(args.fetch("id"))
      supplement.discard!
      { supplement: serialize_supplement(supplement) }
    end

    def handle_restore_supplement(args)
      supplement = Current.user.supplements.find(args.fetch("id"))
      supplement.restore!
      { supplement: serialize_supplement(supplement) }
    end

    def handle_list_habits(args)
      scope = args["archived"].to_s == "true" ? Current.user.checklist_templates.discarded.order(:label) : Current.user.checklist_templates.kept.ordered
      { habits: scope.map { |t| serialize_habit(t) } }
    end

    def handle_create_habit(args)
      attrs = args.slice("label", "description", "icon")
      template = Current.user.checklist_templates.new(attrs)
      template.position = ChecklistTemplate.next_position(user: Current.user)
      template.save!
      { habit: serialize_habit(template) }
    end

    def handle_update_habit(args)
      template = Current.user.checklist_templates.find(args.fetch("id"))
      attrs = args.slice("label", "description", "icon", "position").compact
      raise ToolArgumentError, "no updatable fields provided" if attrs.empty?

      template.update!(attrs)
      { habit: serialize_habit(template) }
    end

    def handle_archive_habit(args)
      template = Current.user.checklist_templates.find(args.fetch("id"))
      template.discard!
      { habit: serialize_habit(template) }
    end

    def handle_restore_habit(args)
      template = Current.user.checklist_templates.find(args.fetch("id"))
      template.restore_at_end!
      { habit: serialize_habit(template) }
    end

    # ----- Settings: macro targets -----

    def handle_update_plan(args)
      plan = Current.user.plans.find_by(slug: args.fetch("slug")) ||
        raise(ToolArgumentError, "no plan with slug \"#{args['slug']}\"; valid slugs: exercise, active, rest")

      attrs = args.slice("target_kcal", "target_protein_g", "target_carbs_g", "target_fat_g").compact
      raise ToolArgumentError, "no updatable fields provided" if attrs.empty?

      plan.update!(attrs)
      { plan: serialize_plan(plan) }
    end

    def handle_update_meal(args)
      meal = resolve_meal(args)
      # `name` is the lookup key, not an updatable field via this tool; use the
      # REST PATCH /api/v1/meals/:id directly if you need to rename a meal.
      attrs = args.slice("scheduled_time", "target_kcal", "target_protein_g",
                          "target_carbs_g", "target_fat_g").compact
      raise ToolArgumentError, "no updatable fields provided" if attrs.empty?

      meal.update!(attrs)
      { meal: serialize_meal(meal.reload) }
    end

    def handle_update_goal(args)
      metric = args.fetch("metric").to_s
      raise ToolArgumentError, "unknown metric \"#{metric}\"; valid: #{Goal.metrics.keys.join(', ')}" unless Goal.metrics.key?(metric)

      goal = Current.user.goals.find_by(metric: Goal.metrics[metric]) ||
        raise(ToolArgumentError, "no goal exists for metric \"#{metric}\"")

      goal.update!(target_value: args.fetch("target_value"))
      { goal: serialize_goal(goal) }
    end

    def handle_copy_yesterday_meals(args)
      target_date = date_arg(args)
      yesterday = Current.user.daily_logs.find_by(date: target_date - 1)

      raise ToolArgumentError, "no_yesterday_log: no log from yesterday — nothing to copy" if yesterday.nil?

      existing_today = Current.user.daily_logs.find_by(date: target_date)
      if existing_today && !existing_today.can_copy_from?(yesterday)
        raise ToolArgumentError, "plan_mismatch: yesterday's plan (#{yesterday.plan.slug}) doesn't match today's (#{existing_today.plan.slug})"
      end

      today = existing_today || DailyLog.for(Current.user, target_date, default_plan: yesterday.plan)
      copied = today.copy_completions_from(yesterday)
      { ok: true, copied: copied, day: serialize_day(today.reload) }
    end

    def resolve_food(query)
      Food.where("LOWER(name) LIKE ?", "%#{query.downcase}%").first ||
        raise(ToolArgumentError, "no food matches \"#{query}\" — call search_foods to find the canonical name")
    end

    # ----- Meal-item management (food items inside a planned meal) -----

    def handle_list_meal_items(args)
      meal = resolve_meal_for_items(args)
      { meal_items: meal.meal_items.includes(:food).map { |i| serialize_meal_item(i) } }
    end

    def handle_add_meal_item(args)
      meal = resolve_meal_for_items(args)
      food = resolve_food(args.fetch("food_name"))
      # Idempotent: same upsert semantics as the REST endpoint — see
      # Api::V1::MealItemsController#create for the reasoning.
      item = meal.meal_items.find_or_initialize_by(food: food)
      item.quantity_grams = args.fetch("quantity_grams")
      item.save!
      { meal_item: serialize_meal_item(item) }
    end

    def handle_update_meal_item(args)
      item = resolve_meal_item(args)
      item.update!(quantity_grams: args.fetch("quantity_grams"))
      { meal_item: serialize_meal_item(item.reload) }
    end

    def handle_remove_meal_item(args)
      item = resolve_meal_item(args)
      id = item.id
      item.destroy!
      { removed: true, id: id }
    end

    # `name` from resolve_meal collides with our meal_name arg, so wrap with a
    # shim that maps meal_name → name before delegating.
    def resolve_meal_for_items(args)
      resolve_meal(args.merge("name" => args.fetch("meal_name")))
    end

    def resolve_meal_item(args)
      meal = resolve_meal_for_items(args)
      food_name = args.fetch("food_name").to_s.downcase
      meal.meal_items.includes(:food).find { |i| i.food.name.downcase == food_name } ||
        raise(ToolArgumentError,
              "no food matching \"#{args['food_name']}\" in meal \"#{meal.name}\"; current items: #{meal.meal_items.includes(:food).map { |i| i.food.name }.join(', ')}")
    end

    def resolve_meal(args)
      plan = plan_for(args)
      plan.meals.find { |m| m.name.casecmp?(args.fetch("name")) } ||
        raise(ToolArgumentError, "no meal \"#{args['name']}\" on plan \"#{plan.slug}\"; available: #{plan.meals.pluck(:name).join(', ')}")
    end

    # ----- Tool registry. Schemas mirror the Zod definitions in the
    # ----- existing Node MCP server (mcp/index.js); see that file for
    # ----- prose descriptions of each parameter's intent.

    ISO_DATE_PATTERN = '^\\d{4}-\\d{2}-\\d{2}$'.freeze
    PLAN_SLUGS       = [ Plan::EXERCISE_SLUG, Plan::ACTIVE_SLUG, Plan::REST_SLUG ].freeze
    DATE_PROP        = { type: "string", pattern: ISO_DATE_PATTERN, description: "YYYY-MM-DD; defaults to today when omitted" }.freeze

    TOOLS = [
      {
        name:        "get_today_status",
        description: "Today's plan, macro targets, consumed macros, weight, completed meals, now_meal, and logged foods.",
        inputSchema: { type: "object", properties: {} },
        handler:     :handle_get_today_status
      },
      {
        name:        "get_day_status",
        description: "Same shape as get_today_status, for a specific date (YYYY-MM-DD).",
        inputSchema: { type: "object", properties: { "date" => DATE_PROP }, required: %w[date] },
        handler:     :handle_get_day_status
      },
      {
        name:        "get_weekly_summary",
        description: "Rolling 7-day recap: avg habits adherence %, weight delta in kg (negative = weight loss), meal completion %, supplement adherence %. Any metric may be null when there's no data to compute it.",
        inputSchema: { type: "object", properties: {} },
        handler:     :handle_get_weekly_summary
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
        handler: :handle_log_weight
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
        handler: :handle_complete_meal
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
        handler: :handle_uncomplete_meal
      },
      {
        name:        "copy_yesterday_meals",
        description: "Marks the target day's meals as complete using the day before's completions, when both share a plan. Idempotent — already-completed meals are preserved. Pass `date` to copy onto a past day; defaults to today.",
        inputSchema: {
          type: "object",
          properties: { "date" => DATE_PROP }
        },
        handler: :handle_copy_yesterday_meals
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
        handler: :handle_log_food
      },
      {
        name:        "delete_logged_food",
        description: "Remove a previously logged food by its id (find ids via get_today_status or get_day_status).",
        inputSchema: {
          type: "object",
          properties: { "id" => { type: "integer", exclusiveMinimum: 0 } },
          required: %w[id]
        },
        handler: :handle_delete_logged_food
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
        handler: :handle_set_plan_for_day
      },
      {
        name:        "list_goals",
        description: "All tracked goals (weight, body fat, HDL, etc.) with current value, target, and progress percent.",
        inputSchema: { type: "object", properties: {} },
        handler:     :handle_list_goals
      },
      {
        name:        "search_foods",
        description: "Find the canonical name of a food before logging it. Case-insensitive partial match, top 20.",
        inputSchema: {
          type: "object",
          properties: { "q" => { type: "string" } },
          required: %w[q]
        },
        handler: :handle_search_foods
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
        handler: :handle_create_food
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
        handler: :handle_active_meals
      },

      # ----- Supplements (templates, not completions) -----
      {
        name:        "list_supplements",
        description: "List supplements. Default returns active (non-archived) sorted by critical first then name. Pass archived=true for the archived list.",
        inputSchema: {
          type: "object",
          properties: { "archived" => { type: "boolean", default: false } }
        },
        handler: :handle_list_supplements
      },
      {
        name:        "create_supplement",
        description: "Add a supplement. time_slots is an optional list of slot keys (morning, pre_lunch, dinner, pre_sleep) — each becomes a row on /supplements at that time.",
        inputSchema: {
          type: "object",
          properties: {
            "name"              => { type: "string" },
            "dose"              => { type: "string", description: "e.g. '1 capsule' or '5 g'" },
            "critical"          => { type: "boolean", default: false },
            "notes"             => { type: "string" },
            "contraindications" => { type: "string" },
            "time_slots"        => { type: "array", items: { type: "string", enum: %w[morning pre_lunch dinner pre_sleep] } }
          },
          required: %w[name dose]
        },
        handler: :handle_create_supplement
      },
      {
        name:        "update_supplement",
        description: "Edit a supplement by id. Any provided field is updated; omitted fields are unchanged. Pass time_slots to fully replace the slot assignments (omit to leave them alone).",
        inputSchema: {
          type: "object",
          properties: {
            "id"                => { type: "integer", exclusiveMinimum: 0 },
            "name"              => { type: "string" },
            "dose"              => { type: "string" },
            "critical"          => { type: "boolean" },
            "notes"             => { type: "string" },
            "contraindications" => { type: "string" },
            "time_slots"        => { type: "array", items: { type: "string", enum: %w[morning pre_lunch dinner pre_sleep] } }
          },
          required: %w[id]
        },
        handler: :handle_update_supplement
      },
      {
        name:        "archive_supplement",
        description: "Soft-delete a supplement: it disappears from /supplements and the rolling adherence calc, but past completion records remain.",
        inputSchema: {
          type: "object",
          properties: { "id" => { type: "integer", exclusiveMinimum: 0 } },
          required: %w[id]
        },
        handler: :handle_archive_supplement
      },
      {
        name:        "restore_supplement",
        description: "Un-archive a supplement (clears discarded_at).",
        inputSchema: {
          type: "object",
          properties: { "id" => { type: "integer", exclusiveMinimum: 0 } },
          required: %w[id]
        },
        handler: :handle_restore_supplement
      },

      # ----- Habits (ChecklistTemplate) -----
      {
        name:        "list_habits",
        description: "List habit templates. Default returns active (non-archived) in display order. Pass archived=true for the archived list.",
        inputSchema: {
          type: "object",
          properties: { "archived" => { type: "boolean", default: false } }
        },
        handler: :handle_list_habits
      },
      {
        name:        "create_habit",
        description: "Add a habit. New habits get appended at the bottom of the order.",
        inputSchema: {
          type: "object",
          properties: {
            "label"       => { type: "string" },
            "description" => { type: "string" },
            "icon"        => { type: "string", description: "single emoji, optional" }
          },
          required: %w[label]
        },
        handler: :handle_create_habit
      },
      {
        name:        "update_habit",
        description: "Edit a habit by id. Pass an integer position to reorder (lower = earlier on /checklist).",
        inputSchema: {
          type: "object",
          properties: {
            "id"          => { type: "integer", exclusiveMinimum: 0 },
            "label"       => { type: "string" },
            "description" => { type: "string" },
            "icon"        => { type: "string" },
            "position"    => { type: "integer", minimum: 0 }
          },
          required: %w[id]
        },
        handler: :handle_update_habit
      },
      {
        name:        "archive_habit",
        description: "Soft-delete a habit: it disappears from /checklist and the adherence calc, but past completion records remain.",
        inputSchema: {
          type: "object",
          properties: { "id" => { type: "integer", exclusiveMinimum: 0 } },
          required: %w[id]
        },
        handler: :handle_archive_habit
      },
      {
        name:        "restore_habit",
        description: "Un-archive a habit; it's appended at the bottom of the order.",
        inputSchema: {
          type: "object",
          properties: { "id" => { type: "integer", exclusiveMinimum: 0 } },
          required: %w[id]
        },
        handler: :handle_restore_habit
      },

      # ----- Settings: macro targets (plan/meal/goal) -----
      {
        name:        "update_plan",
        description: "Update macro targets for one of the three day types (exercise/active/rest). Pass any subset of target_kcal, target_protein_g, target_carbs_g, target_fat_g — omitted fields are unchanged.",
        inputSchema: {
          type: "object",
          properties: {
            "slug"             => { type: "string", enum: PLAN_SLUGS },
            "target_kcal"      => { type: "integer", exclusiveMinimum: 0 },
            "target_protein_g" => { type: "number",  exclusiveMinimum: 0 },
            "target_carbs_g"   => { type: "number",  exclusiveMinimum: 0 },
            "target_fat_g"     => { type: "number",  exclusiveMinimum: 0 }
          },
          required: %w[slug]
        },
        handler: :handle_update_plan
      },
      {
        name:        "update_meal",
        description: "Update one meal on a plan: reschedule (HH:MM in 24-hour) or change per-meal macro targets. Looks up the meal by name on the given plan (defaults to today's plan if plan_slug omitted). To rename a meal, use the REST API directly (PATCH /api/v1/meals/:id).",
        inputSchema: {
          type: "object",
          properties: {
            "plan_slug"        => { type: "string", enum: PLAN_SLUGS },
            "name"             => { type: "string", description: "meal name to look up, e.g. 'Breakfast' (not renamed by this tool)" },
            "scheduled_time"   => { type: "string", pattern: '^\\d{1,2}:\\d{2}$', description: "HH:MM in 24-hour clock" },
            "target_kcal"      => { type: "integer", exclusiveMinimum: 0 },
            "target_protein_g" => { type: "number",  exclusiveMinimum: 0 },
            "target_carbs_g"   => { type: "number",  exclusiveMinimum: 0 },
            "target_fat_g"     => { type: "number",  exclusiveMinimum: 0 }
          },
          required: %w[name]
        },
        handler: :handle_update_meal
      },
      {
        name:        "update_goal",
        description: "Update the target_value for a tracked goal. Lookup is by metric (weight_kg, body_fat_pct, hdl, hs_crp, visceral_fat, muscle_mass_kg).",
        inputSchema: {
          type: "object",
          properties: {
            "metric"       => { type: "string", enum: Goal.metrics.keys },
            "target_value" => { type: "number" }
          },
          required: %w[metric target_value]
        },
        handler: :handle_update_goal
      },

      # ----- Meal-item CRUD (food items inside a planned meal) -----
      {
        name:        "list_meal_items",
        description: "List the food items inside one meal on a plan, with computed kcal and macros per item.",
        inputSchema: {
          type: "object",
          properties: {
            "plan_slug" => { type: "string", enum: PLAN_SLUGS },
            "meal_name" => { type: "string", description: "meal name, e.g. 'Breakfast'" }
          },
          required: %w[meal_name]
        },
        handler: :handle_list_meal_items
      },
      {
        name:        "add_meal_item",
        description: "Add a food to a meal at a given gram quantity. Resolves the food by partial-name match (call search_foods if unsure).",
        inputSchema: {
          type: "object",
          properties: {
            "plan_slug"      => { type: "string", enum: PLAN_SLUGS },
            "meal_name"      => { type: "string" },
            "food_name"      => { type: "string" },
            "quantity_grams" => { type: "number", exclusiveMinimum: 0 }
          },
          required: %w[meal_name food_name quantity_grams]
        },
        handler: :handle_add_meal_item
      },
      {
        name:        "update_meal_item",
        description: "Change the gram quantity of an existing food item in a meal. Highest-leverage portion-correction tool.",
        inputSchema: {
          type: "object",
          properties: {
            "plan_slug"      => { type: "string", enum: PLAN_SLUGS },
            "meal_name"      => { type: "string" },
            "food_name"      => { type: "string", description: "name of the food currently in the meal" },
            "quantity_grams" => { type: "number", exclusiveMinimum: 0 }
          },
          required: %w[meal_name food_name quantity_grams]
        },
        handler: :handle_update_meal_item
      },
      {
        name:        "remove_meal_item",
        description: "Remove a food from a meal entirely (e.g., dropping a stacked fat source like walnuts when the meal already has EVOO + avocado).",
        inputSchema: {
          type: "object",
          properties: {
            "plan_slug" => { type: "string", enum: PLAN_SLUGS },
            "meal_name" => { type: "string" },
            "food_name" => { type: "string" }
          },
          required: %w[meal_name food_name]
        },
        handler: :handle_remove_meal_item
      }
    ].freeze
  end
end
