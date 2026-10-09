import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { reapRun } from "./index.ts";
import {
	fakeBurrowClient,
	fakeExec,
	fakeFs,
	makeBurrow,
	reapDeps,
	setup,
} from "./test-helpers.ts";

describe("reapRun dropped-commit recovery", () => {
	let ctx: Awaited<ReturnType<typeof setup>>;

	beforeEach(async () => {
		ctx = await setup();
	});

	afterEach(async () => {
		await ctx.db.close();
	});

	test("pushes tracked dirty changes to a rescue ref before destroying the workspace", async () => {
		const fs = fakeFs();
		const exec = fakeExec({ revListCount: "0", gitStatus: " M docs/guide.md" });
		const result = await reapRun({
			runId: ctx.runId,
			outcome: "succeeded",
			repos: ctx.repos,
			...reapDeps(fakeBurrowClient(makeBurrow()), {
				fs: fs.fs,
				exec: exec.exec,
			}),
			broker: ctx.broker,
			fs: fs.fs,
			exec: exec.exec,
		});

		expect(result.failureReason).toBe("dropped_commit");
		expect(result.salvageRescueRef).toBe(`warren/rescue/${ctx.runId}`);
		expect(result.workspaceDestroyed).toBe(true);
		expect(
			exec.calls.some(
				(call) => call.args[0] === "add" && call.args[1] === "-u",
			),
		).toBe(true);
		expect(exec.calls.some((call) => call.args.includes("commit"))).toBe(true);
		const row = await ctx.repos.runs.require(ctx.runId);
		expect(row.salvageRef).toBe(`warren/rescue/${ctx.runId}`);
	});

	test("preserves the workspace when untracked changes prevent tracked-only salvage", async () => {
		const fs = fakeFs();
		const exec = fakeExec({
			revListCount: "0",
			gitStatus: "?? docs/new-guide.md",
		});
		const result = await reapRun({
			runId: ctx.runId,
			outcome: "succeeded",
			repos: ctx.repos,
			...reapDeps(fakeBurrowClient(makeBurrow()), {
				fs: fs.fs,
				exec: exec.exec,
			}),
			broker: ctx.broker,
			fs: fs.fs,
			exec: exec.exec,
		});

		expect(result.failureReason).toBe("dropped_commit");
		expect(result.salvageRescueRef).toBeNull();
		expect(result.workspaceDestroyed).toBe(false);
		expect(exec.calls.some((call) => call.args.includes("commit"))).toBe(false);
	});
	test("keeps the workspace when the rescue ref cannot be pushed", async () => {
		const fs = fakeFs();
		const exec = fakeExec({ revListCount: "0", gitStatus: " M docs/guide.md" });
		const rescueFailingExec = {
			run: async (
				cmd: string,
				args: readonly string[],
				options: Parameters<typeof exec.exec.run>[2],
			) => {
				if (args[0] === "push" && args[2]?.includes("warren/rescue/")) {
					throw new Error("remote unavailable");
				}
				return exec.exec.run(cmd, args, options);
			},
		};
		const result = await reapRun({
			runId: ctx.runId,
			outcome: "succeeded",
			repos: ctx.repos,
			...reapDeps(fakeBurrowClient(makeBurrow()), {
				fs: fs.fs,
				exec: rescueFailingExec,
			}),
			broker: ctx.broker,
			fs: fs.fs,
			exec: rescueFailingExec,
			salvageDir: "/data/salvage",
		});

		expect(result.salvageRescueRef).toBeNull();
		expect(result.workspaceDestroyed).toBe(false);
	});
});
