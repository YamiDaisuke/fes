import { expect } from "@playwright/test";

export async function answerQuestion(page, button, typed) {
  const ask = page.locator("#ask");
  await expect(ask).toBeVisible();
  const question = await page.locator("#ask-question").textContent();
  if (typed !== undefined) await page.locator("#ask-field").fill(typed);
  await ask.getByRole("button", { name: button, exact: true }).click();
  await expect(ask).toBeHidden();
  return question;
}
