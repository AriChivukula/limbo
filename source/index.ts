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
import unfluff from "unfluff";
import urllib from "urllib";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from "fs";

export function makeSync<T>(
  wasAsync: Promise<T>,
): void {
  wasAsync
    .catch((error: Error): void => {
      console.error(error);
    })
    .then((value: any): void => {
      console.info(value);
    })
    .catch((error: Error): void => {
      console.error(error);
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

export async function resolveMessage(message: any): Promise<void> {
  let search: any = await wiki().search(message.text.replace(/<.*>/gi, ""));
  await web.chat.postMessage({
    channel: message.channel,
    text: `<@${message.user}>: ${search.results[0].summary}`,
  });
}

eventAdapter.on("app_mention", (message: any) => makeSync(resolveMessage(message)));

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

export async function scrape(): Promise<void> {
  const config: any = JSON.parse(readFileSync("scrape.json", "ascii"));
  await Promise.all(Object.keys(config).map(async (name: string) => {
    let url = config[name];
    let html = await urllib.request("https://supreme.justia.com/cases/federal/us/482/386/#tab-opinion-1957167");
    let extracted = unfluff(html.data);
    if (!existsSync("scrape")) {
      mkdirSync("scrape");
    }
    writeFileSync("scrape/" + name + ".md", "# " + extracted.title + "\n\n" + extracted.text);
  }));
}

if (require.main === module) {
  makeSync(scrape());
}
