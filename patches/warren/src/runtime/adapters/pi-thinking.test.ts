import { describe, expect, test } from "bun:test";
import { buildPiArgv } from "./pi-argv.ts";

describe("Pi thinking frontmatter", () => {
	test("forwards a configured thinking level to the Pi CLI", () => {
		const argv = buildPiArgv({ thinking: "high" });
		const index = argv.indexOf("--thinking");
		expect(index).toBeGreaterThan(-1);
		expect(argv[index + 1]).toBe("high");
	});

	test("trims whitespace from the configured thinking level", () => {
		const argv = buildPiArgv({ thinking: "  medium  " });
		const index = argv.indexOf("--thinking");
		expect(argv[index + 1]).toBe("medium");
	});
});
