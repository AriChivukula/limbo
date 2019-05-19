import "mocha";

import * as chai from "chai";
import {
  readFileSync,
} from "fs";
import {
  join,
} from "path";
import {
  launch,
} from "puppeteer";

import {
  shouldRefreshPage,
} from "../source/content_westlaw";

it(
  "shouldRefreshPage",
  async (): Promise<void> => {
    chai.expect(shouldRefreshPage("https://westlaw.com/")).to.be.true;
    chai.expect(shouldRefreshPage("https://next.westlaw.com/blah/")).to.be.true;
    chai.expect(shouldRefreshPage("https://worstlaw.com/")).to.be.false;
  },
);

it(
  "extensionCanLoad",
  async (): Promise<void> => {
    const browser = await launch({ args: [ "--no-sandbox" ] });
    const page = await browser.newPage();
    await page.goto(`file:${join(__dirname, "test.html")}`);
    const script = readFileSync("build/content.js");
    const ctx = await page.mainFrame().executionContext();
    const result = await ctx.evaluateHandle(script.toString());
    chai.expect(JSON.stringify(result.jsonValue())).to.equal("{}");
    await browser.close();
  },
);
