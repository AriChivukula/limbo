import "@babel/polyfill";

import {
  WebClient,
} from "@slack/client";
import {
  createEventAdapter,
  SlackEventAdapter,
} from "@slack/events-api";
import {
  createMessageAdapter,
  SlackMessageAdapter,
} from "@slack/interactive-messages";
import lambda from "aws-serverless-express";
import express from "express";
import Rollbar from "rollbar";
import wiki from "wikijs";

export interface MakeSyncResult<T> {
  value?: T;
  error?: Error;
}

export function makeSync<T>(
  wasAsync: Promise<T>,
  result: MakeSyncResult<T>,
): void {
  wasAsync
    .catch((error: Error): void => {
      result.error = error;
    })
    .then((value: any): void => {
      result.value = value;
    })
    .catch((error: Error): void => {
      result.error = error;
    });
}

const app: express.Express = express();
const eventAdapter: SlackEventAdapter = createEventAdapter(process.env.TF_VAR_SLACK_SIGNING_SECRET);
const messageAdapter: SlackMessageAdapter = createMessageAdapter(process.env.TF_VAR_SLACK_SIGNING_SECRET);
const web: WebClient = new WebClient(
  undefined,
  {
    clientId: process.env.TF_VAR_SLACK_CLIENT_ID,
    clientSecret: process.env.TF_VAR_SLACK_CLIENT_SECRET,
    refreshToken: process.env.TF_VAR_SLACK_REFRESH_TOKEN,
  },
);

app.use("/slack/event", eventAdapter.expressMiddleware());
app.use("/slack/message", messageAdapter.expressMiddleware());

export function resolveMessage(message: any): void {
  let result: MakeSyncResult<any> = {};
  makeSync(wiki().search(message.text.replace(/<.*>/gi, "")), result);
  makeSync(
    web.chat.postMessage({
      channel: message.channel,
      text: `<@${message.user}>: ${result.value.results[0].summary()}`,
    }),
    {},
  );
}

eventAdapter.on("app_mention", resolveMessage);

app.use(
  (new Rollbar({
    accessToken: process.env.TF_VAR_ROLLBAR_SERVER,
    verbose: true,
    captureUncaught: true,
    captureUnhandledRejections: true,
  }))
    .errorHandler(),
);

export function handler(
  event: any,
  context: any,
): void {
  lambda.proxy(
    lambda.createServer(
      app,
      undefined,
      [
        "application/octet-stream",
        "font/eot",
        "font/opentype",
        "font/otf",
        "image/jpeg",
        "image/png",
        "image/svg+xml",
      ],
    ),
    event,
    context,
  );
}
