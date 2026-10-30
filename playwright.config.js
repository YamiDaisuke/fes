import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "web/tests",
  forbidOnly: !!process.env.CI,
  use: { baseURL: "http://localhost:8000" },
  projects: [{ name: "webkit-ipad", use: { ...devices["iPad Pro 11 landscape"] } }],
  webServer: {
    command: "npm run serve",
    url: "http://localhost:8000",
    reuseExistingServer: !process.env.CI,
  },
});
