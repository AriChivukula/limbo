import "mocha";

import * as chai from "chai";

import {
  resolveMessage,
} from "../source/index";

it(
  "resolveMessage",
  async (): Promise<void> => {
    resolveMessage({
      channel: "test2",
      text: "test1",
      user: "test3",
    });
  },
);
