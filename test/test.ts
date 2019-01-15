import "mocha";

import * as chai from "chai";

import {
  shouldRefreshPage,
} from "../source/index";

it(
  "shouldRefreshPage",
  async (): Promise<void> => {
    expect(shouldRefreshPage("https://westlaw.com/")).to.be.true;
    expect(shouldRefreshPage("https://next.westlaw.com/blah/")).to.be.true;
    expect(shouldRefreshPage("https://worstlaw.com/")).to.be.false;
  },
);
