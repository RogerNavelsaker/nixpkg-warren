import { describe, expect, test } from "bun:test";
import { VALID_TRIGGER } from "./schema.test-helpers.ts";
import { DefaultsConfigSchema, TriggersConfigSchema } from "./schema.ts";

describe("Pi thinking configuration", () => {
	test("accepts thinking level on defaults and cron triggers", () => {
		expect(
			DefaultsConfigSchema.safeParse({ defaultThinking: "high" }).success,
		).toBe(true);
		expect(
			TriggersConfigSchema.safeParse([{ ...VALID_TRIGGER, thinking: "low" }])
				.success,
		).toBe(true);
	});

	test("rejects unsupported thinking levels", () => {
		expect(
			DefaultsConfigSchema.safeParse({ defaultThinking: "turbo" }).success,
		).toBe(false);
		expect(
			TriggersConfigSchema.safeParse([{ ...VALID_TRIGGER, thinking: "turbo" }])
				.success,
		).toBe(false);
	});

	test("accepts action role and model on a cron trigger", () => {
		const parsed = TriggersConfigSchema.safeParse([
			{ ...VALID_TRIGGER, actionRole: "reviewer", actionModel: "local/qwen" },
		]);
		expect(parsed.success).toBe(true);
	});
});
