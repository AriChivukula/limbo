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

eventAdapter.on("message", (message: any, body: any): void => {
  if (message.channel_type !== "channel" || message.subtype) {
    console.log("Did Ignore", message, body);
    return;
  }
  console.log("Replied To", message, body);
  web.chat.postMessage({
    channel: message.channel,
    text: `Hello <@${message.user}>! :tada:`,
    thread_ts: message.ts,
  })
    .then((response: any): void => {
      console.log("Did Reply", response);
    })
    .catch((error: Error): void => {
      console.log("Didn't Reply", error);
    });
  return;
});

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
