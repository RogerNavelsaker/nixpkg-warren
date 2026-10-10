import { describe, expect, test } from "bun:test";
import { dispatchAutoPlanRuns } from "./auto-plan-run.ts";

describe("auto-plan-run action role", () => {
	test.each([
		"actionRole",
		"action_role",
	] as const)("uses %s for child plans", async (key) => {
		const created: { agentName?: string }[] = [];
		const run = {
			id: "run-parent",
			agentName: "planner",
			renderedAgentJson: { frontmatter: { [key]: "reviewer" } },
		};
		const result = await dispatchAutoPlanRuns({
			run,
			project: {
				id: "project",
				defaultBranch: "main",
				localPath: "/projects/example",
			},
			workspacePlanIds: new Set(["plan-new"]),
			baselinePlanIds: new Set(),
			workspacePlansBody:
				'{"id":"plan-new","status":"approved","children":["seed-1"]}\n',
			planRuns: {
				create: async (input) => {
					created.push({ agentName: input.agentName });
					return { planRun: { id: "plan-run-child" } };
				},
			},
			emit: async () => undefined,
			fail: async () => undefined,
		});

		expect(result.created).toBe(true);
		expect(created).toEqual([{ agentName: "reviewer" }]);
	});
});
