import { test as base, webkit, devices } from "@playwright/test";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";

// OPFS throws UnknownError in Playwright's default ephemeral WebKit context; a persistent profile has working OPFS.
export const test = base.extend({
  context: async ({ baseURL }, use) => {
    const profile = await mkdtemp(path.join(tmpdir(), "fes-profile-"));
    const { defaultBrowserType, ...iPad } = devices["iPad Pro 11 landscape"];
    const context = await webkit.launchPersistentContext(profile, { ...iPad, baseURL });
    await use(context);
    await context.close();
    await rm(profile, { recursive: true, force: true });
  },
});

export { expect } from "@playwright/test";
