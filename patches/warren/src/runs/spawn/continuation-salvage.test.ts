import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { openDatabase, type WarrenDb } from "../../db/client.ts";
import { createRepos } from "../../db/repos/index.ts";
import type { SpawnRunInput } from "./types.ts";
import { resolveContinuationRef } from "./continuation.ts";

describe("resolveContinuationRef salvage base", () => {
	let db: WarrenDb;
	let repos: ReturnType<typeof createRepos>;
	let project: Awaited<ReturnType<typeof repos.projects.create>>;
	let parentId: string;

	beforeEach(async () => {
		db = await openDatabase({ path: ":memory:" });
		repos = createRepos(db);
		project = await repos.projects.create({
			gitUrl: "https://github.com/x/y.git",
			localPath: "/data/projects/x/y",
			defaultBranch: "main",
		});
		const parent = await repos.runs.create({
			agentName: "refactor-bot",
			projectId: project.id,
			prompt: "first pass",
			renderedAgentJson: {},
			trigger: "manual",
		});
		parentId = parent.id;
		await repos.runs.setSalvage(parentId, {
			rescueRef: `warren/rescue/${parentId}`,
			bundlePath: null,
		});
	});

	afterEach(async () => {
		await db.close();
	});

	test("uses the parent's salvaged ref as the follow-up base", async () => {
		const ref = await resolveContinuationRef(
			{ repos, parentRunId: parentId } as SpawnRunInput,
			project,
			undefined,
		);

		expect(ref).toBe(`warren/rescue/${parentId}`);
	});
});
