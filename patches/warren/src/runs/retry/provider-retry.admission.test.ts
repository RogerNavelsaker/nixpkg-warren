import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { closeOpenDb, fire, setup } from "./provider-retry.test-fixture.ts";
import { PROVIDER_RETRY_EVENTS } from "./provider-retry.ts";

const WINDOW_ENV = "WARREN_AUTOMATIC_RUN_WINDOW";
const previousWindow = process.env[WINDOW_ENV];

beforeEach(() => {
	process.env[WINDOW_ENV] = "02:00-09:00@Europe/Madrid";
});

afterEach(async () => {
	if (previousWindow === undefined) delete process.env[WINDOW_ENV];
	else process.env[WINDOW_ENV] = previousWindow;
	await closeOpenDb();
});

describe("automatic provider retry admission", () => {
	test("does not retry after the failed run pushed commits", async () => {
		const fixture = await setup({ trigger: "ci-fixer" });
		await fixture.repos.runs.setOutcomeFacts(fixture.runId, {
			commitsAhead: 2,
			baseSha: "base-sha",
			filesChanged: 2,
			insertions: 13,
			deletions: 16,
		});
		await fixture.repos.events.append({
			runId: fixture.runId,
			sandboxEventSeq: 2,
			ts: new Date().toISOString(),
			kind: "reap.branch_pushed",
			stream: "system",
			payload: {
				branch: "warren/run_existing",
				baseBranch: "main",
				commitsAhead: 2,
			},
		});
		const { spawn } = await fire(fixture, {
			now: () => new Date("2026-06-01T00:00:00.000Z"),
		});

		expect(spawn.calls).toHaveLength(0);
		const events = await fixture.repos.events.listByRun(fixture.runId);
		const skipped = events.find(
			(event) => event.kind === PROVIDER_RETRY_EVENTS.retrySkipped,
		);
		expect(skipped?.payloadJson).toMatchObject({
			verdict: "work_already_pushed",
			commitsAhead: 2,
		});
	});

	test("does not retry an automatic run outside the local-model window", async () => {
		const fixture = await setup({ trigger: "cron" });
		const { spawn } = await fire(fixture, {
			now: () => new Date("2026-06-01T07:00:00.000Z"),
		});

		expect(spawn.calls).toHaveLength(0);
		const events = await fixture.repos.events.listByRun(fixture.runId);
		const skipped = events.find(
			(event) => event.kind === PROVIDER_RETRY_EVENTS.retrySkipped,
		);
		expect(skipped?.payloadJson).toMatchObject({
			verdict: "automatic_admission_denied",
		});
	});

	test("does not retry an automatic run when another automatic run occupies capacity", async () => {
		const fixture = await setup({ trigger: "cron" });
		await fixture.repos.runs.create({
			agentName: "refactor-bot",
			projectId: fixture.projectId,
			prompt: "already running",
			renderedAgentJson: {},
			trigger: "scheduled",
		});
		const { spawn } = await fire(fixture, {
			now: () => new Date("2026-06-01T00:00:00.000Z"),
		});

		expect(spawn.calls).toHaveLength(0);
	});

	test("keeps automatic provider retries on their original local provider and model", async () => {
		const fixture = await setup({
			trigger: "cron",
			frontmatter: { provider: "lemonade-server", model: "Qwen3.6-35B-A3B" },
		});
		const { spawn } = await fire(fixture, {
			now: () => new Date("2026-06-01T00:00:00.000Z"),
		});

		expect(spawn.calls).toHaveLength(1);
		expect(spawn.calls[0]).toMatchObject({
			providerOverride: "lemonade-server",
			modelOverride: "Qwen3.6-35B-A3B",
		});
	});
});
