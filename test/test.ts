import "mocha";

import * as chai from "chai";

import {
  shouldRefreshPage,
} from "../source/index";

it(
  "shouldRefreshPage",
  async (): Promise<void> => {
    chai.expect(shouldRefreshPage("https://westlaw.com/")).to.be.true;
    chai.expect(shouldRefreshPage("https://next.westlaw.com/blah/")).to.be.true;
    chai.expect(shouldRefreshPage("https://worstlaw.com/")).to.be.false;
  },
);
