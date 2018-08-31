import "@babel/polyfill";

import lambda from "aws-serverless-express";
import {
  json,
  urlencoded,
} from "body-parser";
import cors from "cors";
import express from "express";
import bearer from "express-bearer-token";
import helmet from "helmet";
import Rollbar from "rollbar";

const app: express.Express = express();

app.use(
  cors(),
  helmet(),
  bearer(),
  json(),
  urlencoded({ extended: true }),
);

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
